# CrossOver system-GStreamer patcher

This tool changes a **CrossOver application**, not a bottle. All bottles in the
selected app will use macOS GStreamer for Wine video playback.

It is useful when a game crashes or fails when opening an in-game video.

## Before you start

- Quit CrossOver and every game running through it.
- Install GStreamer yourself. This tool will never install software.
- Provide a compatible x86_64 `winegstreamer.so` replacement that uses the
  official macOS GStreamer framework.

### Install GStreamer

The recommended option is the official macOS runtime installer from
[GStreamer Downloads](https://gstreamer.freedesktop.org/download/). It installs
the framework this tool expects at `/Library/Frameworks/GStreamer.framework`.

Homebrew is another way to install GStreamer:

```bash
brew install gstreamer
```

Homebrew uses a different installation layout. Do not mix its libraries with an
official GStreamer installation in the same CrossOver app.

## Use the guided tool

```bash
./patch-system-gstreamer.sh
```

Choose a CrossOver app, then follow the prompts. Before changing anything, the
tool shows the app, the bundled files it will set aside, the replacement module,
and the backup location.

To undo the change, run the same command again and choose the patched app. The
tool restores the original files it saved.

## Automation

```bash
./patch-system-gstreamer.sh --apply \
  --app "/Applications/CrossOver.app" \
  --replacement "/path/to/winegstreamer.so"
```

Add `--dry-run` to preview the change without modifying CrossOver. To restore:

```bash
./patch-system-gstreamer.sh --restore \
  --app "/Applications/CrossOver.app"
```

## Safety

The tool creates an app-local backup, refuses to overwrite an existing backup,
and checks the replacement module before modifying CrossOver. It restores moved
files if applying the patch fails part way through.
