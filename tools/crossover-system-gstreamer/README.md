# CrossOver system-GStreamer patcher

This tool changes a **CrossOver application**, not a bottle. Once applied, all
bottles in that app use the macOS GStreamer framework for Wine media playback.
It is intended for video failures caused by CrossOver's limited bundled codecs,
such as Devil May Cry 5 crashing when the customisation menu opens a video.

The tool is separate from game patches because one repaired CrossOver app can
help multiple games.

## What it changes

It moves CrossOver's active bundled GStreamer libraries and plugins out of the
live runtime, then replaces `winegstreamer.so` with a compatible module that
uses macOS GStreamer. It creates a complete app-local backup first and can
restore it exactly.

Recent CrossOver builds use `lib/x86_64`; older patchers often targeted the
obsolete `lib64` location. Leaving the active `lib/x86_64` plugins in place
creates a mixed runtime, which can cause missing-decoder errors even when
GStreamer is installed.

## Requirements

- Quit every CrossOver app before changing one.
- Install the full macOS GStreamer framework, including codecs required by your
  game.
- Use a compatible x86_64 `winegstreamer.so` replacement built to use
  `/Library/Frameworks/GStreamer.framework/Libraries`.

The repository does not distribute replacement modules because they are built
for particular Wine/CrossOver releases.

## Recommended: guided mode

```bash
./patch-system-gstreamer.sh
```

Choose the CrossOver application. The tool shows its state and then guides the
patch, migrates an older partial patch, or offers a restore. It always asks for
confirmation before changing an app.

For an installation patched by the older `GStreamer_Patcher.sh`, choose the
detected **legacy partial patch** entry. The migration retains the original
module backup and, crucially, isolates the active plugin set that the older
script missed.

## Automation

```bash
./patch-system-gstreamer.sh --apply \
  --app "/Applications/CrossOver.app" \
  --replacement "/path/to/winegstreamer.so"
```

To repair an older partial patch without supplying the replacement again:

```bash
./patch-system-gstreamer.sh --migrate-legacy \
  --app "/Applications/CrossOver Preview.app"
```

Add `--dry-run` to preview an operation. To restore an app patched by this
tool:

```bash
./patch-system-gstreamer.sh --restore \
  --app "/Applications/CrossOver Preview.app"
```

## Safety

- The tool refuses unknown or incomplete CrossOver layouts.
- It never overwrites an existing backup.
- It refuses a replacement module that is not x86_64 or does not reference the
  macOS GStreamer framework.
- It refuses restoration if CrossOver has changed the original library paths,
  rather than overwriting an updated app.
- A failed apply restores components already moved before exiting.

CrossOver updates can replace the application bundle. Re-run the guided status
check after an update instead of assuming the patch persists.
