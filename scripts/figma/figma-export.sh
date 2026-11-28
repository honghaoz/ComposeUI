#!/bin/bash

set -euo pipefail

# OVERVIEW:
# Exports layers of a Figma file, or the whole file, through Figma's REST API, as the source for implementing a design to
# the pixel: each layer's JSON, Figma's own renders of the layers as PNGs, and the bitmaps that their fills use.
#
# The JSON has every property of a layer, such as its gradients' stops and handles and its effects' exact settings, and
# the vector paths. Figma's SVG export stands in for its effects with SVG filters, which other renderers draw
# differently, so it doesn't show the design to the pixel.
#
# A file on a free plan allows up to 20 requests a month to the file and render endpoints, so the export skips what it
# already saved, and reports the requests it made.

REPO_ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
KEYCHAIN_SERVICE="io.chouti.composeui.figma-export"

print_help() {
  echo "Usage: $0 <figma-link> [--node <id>]... [--scales <list>] [--out <dir>] [--force]"
  echo "       $0 --save-token | --delete-token"
  echo ""
  echo "  <figma-link>      A link to a file, or to a layer from Copy link to selection, or a file key."
  echo "  --node <id>       Another layer to export, such as 114:477. Repeatable."
  echo "  --scales <list>   The scales to render the layers at, comma separated. Optional. Default is 2,3. Empty for"
  echo "                    no renders."
  echo "  --out <dir>       The folder to save to. Optional. Default is .temp/figma/<file key> in the repository."
  echo "  --force           Request everything again, such as after the design changed."
  echo "  --save-token      Save a personal access token in the login keychain, typed without showing it."
  echo "  --delete-token    Delete the saved token."
  echo ""
  echo "Create the token in Figma's Settings, in Security, under Personal access tokens, with the File content read"
  echo "scope. FIGMA_TOKEN, when set, is used instead of the saved token."
  echo ""
  echo "With layers, the export saves <id>.json and <id>@<scale>x.png for each layer, with the colons of its id as"
  echo "dashes. Without, it saves file.json. Both save the bitmaps of the fills in images/."
}

# A layer's id as the API takes it, from its form in a link, such as 114:477 from 114-477, or I114:477;12:3, a layer in
# an instance, from I114-477%3B12-3.
add_node() { # <id>
  local id id_re='^I?[0-9]+:[0-9]+(;[0-9]+:[0-9]+)*$'
  id=$(echo "$1" | sed -e 's/%3[Aa]/:/g' -e 's/%3[Bb]/;/g' -e 's/-/:/g')
  if ! [[ $id =~ $id_re ]]; then
    echo "🛑 Invalid layer id: '$1'" >&2
    exit 1
  fi
  NODE_IDS="${NODE_IDS:+$NODE_IDS,}$id"
}

SOURCE=""
NODE_IDS=""
SCALES="2,3"
OUT_DIR=""
FORCE=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
  --node)
    add_node "${2:-}"
    shift 2
    ;;
  --scales)
    SCALES="${2:-}"
    shift 2
    ;;
  --out)
    OUT_DIR="${2:-}"
    shift 2
    ;;
  --force)
    FORCE=true
    shift
    ;;
  --save-token)
    echo "Paste the token at both prompts."
    security add-generic-password -U -a "$USER" -s "$KEYCHAIN_SERVICE" -l "Figma personal access token" -w
    echo "✅ Saved the token in the login keychain."
    exit 0
    ;;
  --delete-token)
    if security delete-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" > /dev/null 2>&1; then
      echo "✅ Deleted the saved token."
    else
      echo "No saved token."
    fi
    exit 0
    ;;
  --help | -h)
    print_help
    exit 0
    ;;
  -*)
    echo "🛑 Unknown argument: $1" >&2
    print_help
    exit 1
    ;;
  *)
    if [ -n "$SOURCE" ]; then
      echo "🛑 More than one link: $1" >&2
      exit 1
    fi
    SOURCE=$1
    shift
    ;;
  esac
done

# zsh puts backslashes before the ? = and & of a link pasted outside quotes, which quotes around it then keep
SOURCE=${SOURCE//\\/}

KEY_RE='^[0-9A-Za-z]{22,128}$'
LINK_RE='figma\.com/[a-z]+/([0-9A-Za-z]+)(/branch/([0-9A-Za-z]+))?'
LINK_NODE_RE='[?&]node-id=([^&#]+)'
if [ -z "$SOURCE" ]; then
  echo "🛑 Missing the Figma link." >&2
  print_help
  exit 1
elif [[ $SOURCE =~ $KEY_RE ]]; then
  FILE_KEY=$SOURCE
elif [[ $SOURCE =~ $LINK_RE ]]; then
  # a branch's link has the main file's key and then the branch's, which the API takes for the branch
  FILE_KEY=${BASH_REMATCH[3]:-${BASH_REMATCH[1]}}
  if [[ $SOURCE =~ $LINK_NODE_RE ]]; then
    add_node "${BASH_REMATCH[1]}"
  fi
else
  echo "🛑 Not a Figma link or file key: $SOURCE" >&2
  exit 1
fi

# checked before any request, since a render that fails after the JSON was requested wastes the request
for scale in ${SCALES//,/ }; do
  if ! awk -v s="$scale" 'BEGIN { exit !(s ~ /^[0-9]+(\.[0-9]+)?$/ && s >= 0.01 && s <= 4) }'; then
    echo "🛑 Invalid scale: '$scale' (expected a number from 0.01 to 4)" >&2
    exit 1
  fi
done

OUT_DIR=${OUT_DIR:-$REPO_ROOT/.temp/figma/$FILE_KEY}

if [ -x "$REPO_ROOT/bin/jq" ]; then
  JQ_BIN="$REPO_ROOT/bin/jq"
elif command -v jq > /dev/null; then
  JQ_BIN="jq"
else
  echo "🛑 jq not found. Run make bootstrap or install jq." >&2
  exit 1
fi

if [ -n "${FIGMA_TOKEN:-}" ]; then
  TOKEN=$FIGMA_TOKEN
elif ! TOKEN=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w 2> /dev/null); then
  echo "🛑 No Figma token. Save one with $0 --save-token, or set FIGMA_TOKEN." >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# The requests to the file and render endpoints, the ones that Figma limits the most.
FILE_REQUESTS=0

# The value of a header in a file of response headers.
header() { # <headers file> <lowercase name>
  tr -d '\r' < "$1" | awk -v name="$2:" 'tolower($1) == name { value = $2 } END { print value }'
}

# A number of seconds in the largest unit that keeps it above 1, rounded up.
duration() { # <seconds>
  if [ "$1" -lt 120 ]; then
    echo "$1 seconds"
  elif [ "$1" -lt 7200 ]; then
    echo "$((($1 + 59) / 60)) minutes"
  elif [ "$1" -lt 172800 ]; then
    echo "$((($1 + 3599) / 3600)) hours"
  else
    echo "$((($1 + 86399) / 86400)) days"
  fi
}

# Requests a path of Figma's API with the token, and saves the response only when the request succeeds, so that a failed
# request leaves no file that a later run would skip.
figma_get() { # <path with query> <output file>
  local status retry_after attempt=1
  while true; do
    # curl reads the token's header from its input instead of its arguments, which other processes can read
    status=$(printf 'X-Figma-Token: %s\n' "$TOKEN" |
      curl -sS -H @- -D "$TMP_DIR/headers" -o "$TMP_DIR/body" -w '%{http_code}' "https://api.figma.com$1")
    if [ "$status" = 200 ]; then
      mv "$TMP_DIR/body" "$2"
      return
    fi

    retry_after=$(header "$TMP_DIR/headers" retry-after)
    [[ $retry_after =~ ^[0-9]+$ ]] || retry_after=""
    # a short wait is for a per-minute limit, while a monthly limit can be days away
    if [ "$status" = 429 ] && [ -n "$retry_after" ] && [ "$retry_after" -le 60 ] && [ "$attempt" -lt 3 ]; then
      echo "Waiting ${retry_after}s for Figma's rate limit..."
      sleep "$retry_after"
      attempt=$((attempt + 1))
    else
      break
    fi
  done

  local message
  message=$("$JQ_BIN" -r '.err // .message // empty' "$TMP_DIR/body" 2> /dev/null || true)
  echo "🛑 Figma answered $status to ${1%%\?*}${message:+: $message}" >&2
  case $status in
  403)
    echo "   The token may have expired or lack the File content read scope, or its account can't open the file." >&2
    echo "   Save a new token with $0 --save-token." >&2
    ;;
  404)
    echo "   Check the link. For a Community file, duplicate it into your drafts and export the copy." >&2
    ;;
  429)
    echo "   The $(header "$TMP_DIR/headers" x-figma-rate-limit-type) rate limit of the file's" \
      "$(header "$TMP_DIR/headers" x-figma-plan-tier) plan ran out.${retry_after:+ Try again in $(duration "$retry_after").}" >&2
    ;;
  esac
  exit 1
}

# Downloads a file from a link that the API gave, which needs no token.
download() { # <url> <output file>
  curl -sS --fail -o "$TMP_DIR/download" "$1"
  mv "$TMP_DIR/download" "$2"
}

# The name of a layer's files: its id with the colons as dashes, as in a link, and the semicolons as underscores.
layer_name() { # <id>
  echo "$1" | tr ':;' '-_'
}

mkdir -p "$OUT_DIR"

if [ -z "$NODE_IDS" ]; then
  JSON_FILES=("$OUT_DIR/file.json")
  if $FORCE || [ ! -f "$OUT_DIR/file.json" ]; then
    figma_get "/v1/files/$FILE_KEY?geometry=paths" "$OUT_DIR/file.json"
    FILE_REQUESTS=$((FILE_REQUESTS + 1))
    echo "Saved file.json"
  else
    echo "Skipped file.json, which is already saved."
  fi
  if [ -n "$SCALES" ]; then
    echo "Renders need a layer: link to one, or pass --node."
  fi
else
  JSON_FILES=()
  missing=false
  for id in ${NODE_IDS//,/ }; do
    name=$(layer_name "$id")
    JSON_FILES+=("$OUT_DIR/$name.json")
    [ -f "$OUT_DIR/$name.json" ] || missing=true
    for scale in ${SCALES//,/ }; do
      [ -f "$OUT_DIR/$name@${scale}x.png" ] || missing=true
    done
  done

  # the renders are of the file's version that the JSON is from, so that both show the same design, and a missing file
  # requests them all again instead of mixing versions
  if $FORCE || $missing; then
    figma_get "/v1/files/$FILE_KEY/nodes?ids=${NODE_IDS//;/%3B}&geometry=paths" "$TMP_DIR/nodes.json"
    FILE_REQUESTS=$((FILE_REQUESTS + 1))
    for id in ${NODE_IDS//,/ }; do
      if ! "$JQ_BIN" -e --arg id "$id" '.nodes[$id] != null' "$TMP_DIR/nodes.json" > /dev/null; then
        echo "🛑 The file has no layer $id." >&2
        exit 1
      fi
      # the layer's entry with the file's name and version, which the response has once for all the layers
      name=$(layer_name "$id")
      "$JQ_BIN" --arg id "$id" 'del(.nodes) + .nodes[$id]' "$TMP_DIR/nodes.json" > "$TMP_DIR/layer.json"
      mv "$TMP_DIR/layer.json" "$OUT_DIR/$name.json"
      echo "Saved $name.json"
    done

    version=$("$JQ_BIN" -r '.version // empty' "$TMP_DIR/nodes.json")
    for scale in ${SCALES//,/ }; do
      figma_get "/v1/images/$FILE_KEY?ids=${NODE_IDS//;/%3B}&scale=$scale&format=png${version:+&version=$version}" \
        "$TMP_DIR/renders.json"
      FILE_REQUESTS=$((FILE_REQUESTS + 1))
      for id in ${NODE_IDS//,/ }; do
        url=$("$JQ_BIN" -r --arg id "$id" '.images[$id] // empty' "$TMP_DIR/renders.json")
        if [ -z "$url" ]; then
          echo "🛑 Figma couldn't render layer $id at ${scale}x, such as when it's hidden." >&2
          exit 1
        fi
        name=$(layer_name "$id")
        download "$url" "$OUT_DIR/$name@${scale}x.png"
        echo "Saved $name@${scale}x.png"
      done
    done
  else
    echo "Skipped the layers' JSON and renders, which are already saved."
  fi
fi

# the bitmaps of the fills, which the JSON names by a hash of their content, so that a saved one never changes
missing_refs=""
for ref in $("$JQ_BIN" -r '.. | objects | .imageRef // empty' "${JSON_FILES[@]}" | sort -u); do
  compgen -G "$OUT_DIR/images/$ref.*" > /dev/null || missing_refs="$missing_refs $ref"
done
if [ -n "$missing_refs" ]; then
  figma_get "/v1/files/$FILE_KEY/images" "$TMP_DIR/image-fills.json"
  mkdir -p "$OUT_DIR/images"
  for ref in $missing_refs; do
    # the API returns the links in meta, which its documentation leaves out
    url=$("$JQ_BIN" -r --arg ref "$ref" '(.meta.images // .images)[$ref] // empty' "$TMP_DIR/image-fills.json")
    if [ -z "$url" ]; then
      echo "🛑 Figma has no link for the image $ref." >&2
      exit 1
    fi
    download "$url" "$TMP_DIR/image"
    # the JSON doesn't name the format, so the extension comes from the content
    mime=$(file -b --mime-type "$TMP_DIR/image")
    case $mime in
    image/*) ext=${mime#image/} ;;
    *) ext=bin ;;
    esac
    mv "$TMP_DIR/image" "$OUT_DIR/images/$ref.$ext"
    echo "Saved images/$ref.$ext"
  done
fi

echo "✅ Exported to $OUT_DIR"
echo "   Requests to the file and render endpoints: $FILE_REQUESTS, of up to 20 a month on a free plan."
