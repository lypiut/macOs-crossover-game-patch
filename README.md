# CrossOver game patches for macOS

Compatibility fixes for Windows games running through
[CrossOver](https://www.codeweavers.com/crossover). Each patch includes
installation and restore instructions.

## Available patches

| Game | Fix | Requirements |
| --- | --- | --- |
| [Devil May Cry 5](games/devil-may-cry-5/README.md) | HDR for DirectX 11 and 12 | Supported game build, D3DMetal or DXMT, HDR display |
| [Alan Wake 2](games/alan-wake-2/README.md) | Enables the game's HDR setting | Python 3, compatible graphics backend, HDR display |
| [The Witcher 3](games/witcher-3/README.md) | Unlocks DLSS, frame generation and ray tracing | Steam build 25773555, DirectX 12, D3DMetal with DLSS enabled |

## Runtime tools

| Tool | What it does |
| --- | --- |
| [System GStreamer patcher](tools/crossover-system-gstreamer/README.md) | Fixes some crashes during video playback. Changes the selected CrossOver app and affects all its bottles. |

## Getting started

Download the project using **Code → Download ZIP** on GitHub and extract it.
Open the page for your game above and follow its instructions.

If you use Git:

```bash
git clone https://github.com/lypiut/macOs-crossover-game-patch.git
cd macOs-crossover-game-patch
```

Quit the game before patching and keep any backups the script creates.
Game updates or Steam's **Verify integrity** can remove a patch. CrossOver
updates can replace runtime changes.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) to report a problem or submit a fix.
Report patch issues in this repository.

## Credits

Built on [CrossOver](https://www.codeweavers.com/crossover),
[Wine](https://www.winehq.org/) and
[GStreamer](https://gstreamer.freedesktop.org/).
The DMC5 HDR patch includes shader work adapted from
[RenoDX](https://github.com/clshortfuse/renodx) by Carlos Lopez Jr.; see the
[third-party notices](games/devil-may-cry-5/THIRD_PARTY_NOTICES.md).

## License

Independent community project, unaffiliated with CodeWeavers, Apple, Valve or
the game publishers. You need your own licensed copies of CrossOver and the
games. No game files or proprietary CrossOver components are distributed.

Original code and documentation use the [MIT License](LICENSE). Third-party
work retains its own licenses and attribution.
