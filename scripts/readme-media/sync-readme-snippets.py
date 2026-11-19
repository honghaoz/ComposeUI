"""Copies the README's code snippets from the playground's README demos, so that the README shows the demos' code.

usage: python3 scripts/readme-media/sync-readme-snippets.py [--check]

Run it from the repository root after editing a demo in `playgrounds/Sources/Shared/ReadmeDemos`. Each snippet in
README.md follows a comment that names its demo file and the part of the file it shows, which GitHub doesn't render:

    <!-- snippet: ReadmeDemo05Animations.swift class -->
    ```swift
    ...
    ```

The parts are:

- `quick-start`: from `import ComposeUI` to the end of the first type, without its documentation comment.
- `class`: the body of the file's `ComposeView` subclass.
- `content`: the body of the `content` property.
- `function <name>`: the body of the static function `<name>`.

The script rewrites only the code blocks and leaves the rest of the README unchanged. With --check, it writes nothing,
lists the snippets that differ from their demos and exits with status 1 if any do. It also warns about lines longer than
42 characters, which widen a section's code table past the 447 pixels of the others and leave less room for the image
beside it (see the README in this folder for how the widths are worked out).
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEMOS = os.path.join(ROOT, "playgrounds", "Sources", "Shared", "ReadmeDemos")
README = os.path.join(ROOT, "README.md")
MAX_LINE_LENGTH = 42

SNIPPET = re.compile(r"<!-- snippet: (?P<spec>[^>]+?) -->\n```swift\n(?P<code>.*?)\n```", re.S)


def dedent(lines, width):
    return "\n".join(line[width:] if line.strip() else "" for line in lines).strip("\n")


def body(lines, opening, closing, width, description):
    start = next((index for index, line in enumerate(lines) if opening(line)), None)
    if start is None:
        sys.exit(f"error: no {description}")
    end = next((index for index in range(start + 1, len(lines)) if lines[index] == closing), None)
    if end is None:
        sys.exit(f"error: no end of {description}")
    return dedent(lines[start + 1:end], width)


def extract(spec):
    parts = spec.split()
    name, kind, arguments = parts[0], parts[1], parts[2:]
    lines = open(os.path.join(DEMOS, name), encoding="utf-8").read().split("\n")
    if kind == "quick-start":
        start = lines.index("import ComposeUI")
        end = next(index for index in range(start + 1, len(lines)) if lines[index] == "}")
        return "\n".join(line for line in lines[start:end + 1] if not line.startswith("///")).strip("\n")
    if kind == "class":
        return body(lines, lambda line: re.match(r"^(final )?class \w+: ComposeView \{$", line), "}", 2,
                    f"ComposeView subclass in {name}")
    if kind == "content":
        return body(lines, lambda line: line.strip() == "override var content: ComposeContent {", "  }", 4,
                    f"content property in {name}")
    if kind == "function" and len(arguments) == 1:
        return body(lines, lambda line: line.strip().startswith(f"static func {arguments[0]}("), "  }", 4,
                    f"function {arguments[0]} in {name}")
    sys.exit(f"error: unknown snippet part '{spec}'")


def main():
    check = "--check" in sys.argv[1:]
    readme = open(README, encoding="utf-8").read()
    differing = []
    long_lines = []

    def replace(match):
        spec = match.group("spec")
        code = extract(spec)
        if code != match.group("code"):
            differing.append(spec)
        long_lines.extend((spec, line) for line in code.split("\n") if len(line) > MAX_LINE_LENGTH)
        return f"<!-- snippet: {spec} -->\n```swift\n{code}\n```"

    updated, count = SNIPPET.subn(replace, readme)
    if count == 0:
        sys.exit("error: no snippet comments in README.md")

    for spec, line in long_lines:
        print(f"warning: {spec}: {len(line)} characters, over {MAX_LINE_LENGTH}: {line.strip()}")
    if check:
        for spec in differing:
            print(f"out of sync: {spec}")
        print(f"{count} snippets, {len(differing)} out of sync")
        sys.exit(1 if differing else 0)
    if updated != readme:
        open(README, "w", encoding="utf-8").write(updated)
    print(f"{count} snippets, {len(differing)} updated")


main()
