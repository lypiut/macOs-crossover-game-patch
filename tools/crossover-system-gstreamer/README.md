# CrossOver system-GStreamer patcher

Use this when a CrossOver game crashes as it opens a video: a cutscene, intro,
or menu clip. It lets the selected CrossOver app use macOS GStreamer instead.
Every bottle in that app is affected.

## Before you begin

Quit CrossOver and all Windows apps. Install the official macOS GStreamer
runtime from [GStreamer Downloads](https://gstreamer.freedesktop.org/download/).
The patcher never installs software for you.

## Patch or restore

```bash
./patch-system-gstreamer.sh
```

Choose a CrossOver app and confirm the plan. The tool saves the original runtime
inside that app before making a change. Run the same command later to restore it.

For automation:

```bash
./patch-system-gstreamer.sh --apply --app "/Applications/CrossOver Preview.app"
./patch-system-gstreamer.sh --restore --app "/Applications/CrossOver Preview.app"
```

Add `--dry-run` to preview a change. The patcher refuses to overwrite its
backup and rolls back an incomplete apply.
