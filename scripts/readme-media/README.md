# README media

The images in the README's Usage section are recorded from the AppKit playground's README demos
(`playgrounds/Sources/Shared/ReadmeDemos`). This folder has the tools to record them again.

The media are uploaded to GitHub by dragging them into a pull request or comment box, which gives each file a
`https://github.com/user-attachments/assets/...` URL for the README. GitHub has no API for these uploads, and it limits
an image to 10 MB.

## Code snippets

Each code snippet in the README's Usage section is the code of a demo, so edit the demo in
`playgrounds/Sources/Shared/ReadmeDemos` and copy the change to the README with:

```bash
python3 scripts/readme-media/sync-readme-snippets.py
```

A comment before each snippet in README.md, which GitHub doesn't render, names the demo file and the part it shows, such
as `<!-- snippet: ReadmeDemo05Animations.swift class -->`. `--check` lists the snippets that differ from their demos
without writing, and exits with status 1 if any do. The script also warns about lines longer than 42 characters, which
widen a section's code table past 447 pixels, so the image no longer fits beside the code.

## Layout

Each feature section has the code first, in a one-cell `<table align="left">` with `<td width="447">`, and then the
media in a paragraph, `<p>&nbsp;&nbsp;&nbsp;<img width="360"><br clear="left"></p>`. On a wide README, the image sits
to the right of the code. When the README is too narrow for both, such as on a phone or in a small window, the image
moves below the code, so both keep their full size and stay left-aligned. A two-column table can't do this: its columns
never wrap, and when the table is narrow, the image column shrinks to nothing because the code column can't shrink
below its longest line.

- `align="left"` floats the code table, and the paragraph's line wraps beside it when the image fits and moves below it
  when it doesn't. The table needs the `td` width: GitHub renders a table as `max-content`, and a `td` width works as a
  minimum that GitHub's sanitizer keeps, so the table keeps its width. A plain code block can't float.
- The three non-breaking spaces put a 14 pixel gap between the code and the image. The line can break between them and
  the image, so on a phone the image starts at the left edge. In READMEs about 808 to 822 pixels wide, the image fits
  beside the code but the spaces don't, so it wraps to the next line beside the code, with no gap. `hspace` would add
  the gap on both sides and push the image past the right edge of a phone screen. GitHub's sanitizer removes `<wbr>`
  and `<nobr>`, and putting the image in its own table doubles the border between the two boxes.
- `<br clear="left">` starts the next section below the code, which is usually taller than the image.
- GitHub sizes the cells as border-box, so a cell's width includes its 13 px side padding and its border.
- GitHub puts a 44 px copy button beside each code block, which adds to the code cell's minimum width. A code cell
  needs about `8.19 x <longest line in characters> + 103` pixels: 13.6 px SF Mono, the code block's 16 px side
  padding, the copy button and the cell's padding. 42 characters need 447 pixels.
- The README on the repository's home page is 838 pixels wide at window widths from 1280 to 1920, the narrowest of
  GitHub's README views. The 448 pixel table, the 14 pixel gap and the 360 pixel image fit side by side in READMEs 822
  pixels or wider.

To show longer lines or larger media, change the cell width and the image width in all the sections and the line limit
in `sync-readme-snippets.py` together, keep the table and the image within 838 pixels, and check the README on
github.com in a wide and a narrow window.

## Requirements

- macOS with Xcode, and `ffmpeg` (`brew install ffmpeg`).
- Screen Recording permission for the app that runs the scripts, such as Terminal.
- Accessibility permission for the same app, to record the interaction demo: `drive-mouse` moves the cursor and clicks
  with posted events, which macOS drops without it.
- A 2x (Retina) main display: `record-screen` captures the window at twice its size in points, and `still.sh` uses
  `screencapture -R`, which saves at the display's scale, so on a 1x display the stills come out half size and the
  recordings are upscaled.
- The main display's top-left area free, since the demo window opens at (120, 160) points from its top-left corner.

## Steps

1. Build the AppKit playground in Release:

   ```bash
   xcodebuild -project playgrounds/ComposeUIPlayground.xcodeproj -scheme ComposeUIPlayground-AppKit \
     -configuration Release -derivedDataPath /tmp/readme-media-build build
   APP="/tmp/readme-media-build/Build/Products/Release/ComposéUI.app"
   ```

   Run a demo on its own with `-readmeDemo <name>`, and `-readmeTheme dark` for the dark appearance.

2. Save the stills (720 x 440 pixels):

   ```bash
   scripts/readme-media/still.sh "$APP" layout 02-layout.png
   ```

   The stills are `layout`, `styling`, `text` and `interop`.

3. Record an animation, which writes the raw frames to a folder:

   ```bash
   scripts/readme-media/capture.sh "$APP" animations /tmp/rec/animations 8 220 0
   ```

4. Find where a loop starts: the first frame of a run of motion after a still gap.

   ```bash
   python3 scripts/readme-media/motion.py /tmp/rec/animations
   ```

5. Cut one loop and encode it at 50 fps, starting one frame (0.02 s) before the run of motion:

   ```bash
   python3 scripts/readme-media/make-apng.py /tmp/rec/animations 720 440 <start> 150 \
     05-animations.apng.png --fps 50 -pred mixed -compression_level 9
   ```

   The script reports the largest difference between the first frame and the frame after the last, which is 0 or a
   few levels for a seamless loop.

6. Check the results:

   ```bash
   python3 scripts/readme-media/inspect-apng.py *.apng.png
   ffprobe -v error -count_frames -select_streams v:0 \
     -show_entries stream=width,height,avg_frame_rate,nb_read_frames 05-animations.apng.png
   ```

   Each file should be 720 pixels wide, with every frame delay `1/50`, playing forever, and under 10 MB.

## Recipes

| File | Demo | Capture | Loop | make-apng options |
| --- | --- | --- | --- | --- |
| `02-layout.png` | `layout` | `still.sh` | | |
| `03-styling.png` | `styling` | `still.sh` | | |
| `04-text.png` | `text` | `still.sh` | | |
| `05-animations.apng.png` | `animations` | 8 s, height 220 | 3.0 s, 150 frames | `-pred mixed -compression_level 9` |
| `06-transitions.apng.png` | `transitions` | 8 s, height 220 | 2.6 s, 130 frames | `-pred mixed -compression_level 9` |
| `07-interaction.apng.png` | `interaction` | 7 s, height 220, cursor 1, mouse steps below | 4.6 s, 230 frames | `-pred mixed -compression_level 9` |
| `08-dark-mode.apng.png` | `dark-mode` | 9 s, height 220 | 3.2 s, 160 frames | `-pred mixed -compression_level 9` |
| `09-interop.png` | `interop` | `still.sh` | | |
| `10-scrolling.apng.png` | `scrolling` | frame-hold mode below | 7.6 s, 380 frames | `--palette -pred none -compression_level 9` |

The transitions demo alternates its states with `asyncAfter`, which drifts, so its loop is 2.6 s instead of 2.5 s. Take
the period from `motion.py`.

### Interaction

The demo clicks its button with the real cursor, which `capture.sh` drives with these steps:

```bash
scripts/readme-media/capture.sh "$APP" interaction /tmp/rec/interaction 7 220 1 \
  warp 403 337 sleep 0.5 move 302 272 0.7 sleep 0.45 down sleep 0.15 up sleep 0.8 down sleep 0.15 up \
  sleep 0.45 move 403 337 0.7 sleep 1.5
```

Start the loop 0.35 s before the cursor first moves, and end it after the button's hover fade settles.

### Scrolling

A real-time recording of the scrolling demo misses frames, so the demo has a frame-hold mode that holds each frame of a
50 fps scroll for 4/60 s (4 display frames at 60 Hz, 8 at 120 Hz), and the recording is sped back up:

```bash
APP_ARGS="-readmeFrameHold 4 -readmeFrameRate 50" \
  scripts/readme-media/capture.sh "$APP" scrolling /tmp/rec/scrolling 30 360 0
python3 scripts/readme-media/motion.py /tmp/rec/scrolling --timescale 0.3
python3 scripts/readme-media/make-apng.py /tmp/rec/scrolling 720 720 <start> 380 \
  10-scrolling.apng.png --fps 50 --timescale 0.3 --palette -pred none -compression_level 9
```

The timescale is 60 / (4 x 50) = 0.3. Start at the first frame of the first run of motion, not before it: the labels in
the very first recorded frame are drawn ahead of time by another path, and differ by a few levels from the same labels
drawn later.
