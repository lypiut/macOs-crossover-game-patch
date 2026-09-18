# CrossOver game patches for macOS

Community-made compatibility fixes for Windows games running through
[CrossOver](https://www.codeweavers.com/crossover) on macOS.

The project focuses on small, documented, and reversible changes. Each patch is
limited to a known game build, checks files before modifying them, creates a
backup where applicable, and includes a restore path.

> [!IMPORTANT]
> This is an independent community project. It is not affiliated with or
> endorsed by CodeWeavers, Apple, Valve, Capcom, or any other game publisher.
> You must provide your own licensed copies of CrossOver and the games.

## Available patches

| Patch | What it does | Requirements |
| --- | --- | --- |
| [Devil May Cry 5 — HDR](games/devil-may-cry-5/README.md) | Enables the game's native HDR paths in DirectX 11 and DirectX 12, with HDR shader replacements adapted from RenoDX. | CrossOver with D3DMetal or DXMT, an HDR display, and the supported DMC5 build |

[Installation, HDR captures, and technical details →](games/devil-may-cry-5/README.md)

## Runtime tools

| Tool | Use case | Scope |
| --- | --- | --- |
| [System GStreamer patcher](tools/crossover-system-gstreamer/README.md) | Helps with crashes when a game opens a cutscene, intro, or menu video. | Modifies the selected CrossOver application and therefore affects all of its bottles. |

## Getting started

Clone the repository:

```bash
git clone https://github.com/lypiut/macOs-crossover-game-patch.git
cd macOs-crossover-game-patch
```

Then open the documentation for the patch or tool you need. For example:

```bash
cd games/devil-may-cry-5
./patch-hdr.sh
```

The patchers are interactive by default and show the planned changes before
asking for confirmation. Command-line and restore instructions are documented
on each patch's page.

## Safety and project principles

- Quit the game—and CrossOver when instructed—before changing files.
- Read the patch-specific requirements; unsupported game builds are refused.
- Keep the generated backups until you have confirmed that the game works.
- Steam's **Verify integrity of game files** can remove installed patches.
- CrossOver updates may replace runtime changes or make them incompatible.
- Review the shell scripts before running them. The scripts and their exact
  file operations are intentionally kept readable.

No game executable, game asset, or proprietary CrossOver component is
distributed by this project. Patches operate on files already installed by the
user.

## Contributing

Bug reports, compatibility results, documentation improvements, and new
patches are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before
opening an issue or pull request. It explains what diagnostic information to
include and the safety, testing, and licensing requirements for new patches.

## Credits and upstream projects

This work builds on the macOS gaming and open-source compatibility ecosystem:

- [CodeWeavers CrossOver](https://www.codeweavers.com/crossover) makes running
  Windows software on macOS possible and contributes extensively to Wine.
- [Wine](https://www.winehq.org/) provides the open-source Windows
  compatibility layer at the heart of CrossOver.
- [GStreamer](https://gstreamer.freedesktop.org/) provides the open-source
  multimedia framework used by the video compatibility tool.
- [RenoDX](https://github.com/clshortfuse/renodx), by Carlos Lopez Jr., is the
  source of the shader work adapted for the DMC5 HDR patch. See the
  [third-party notices](games/devil-may-cry-5/THIRD_PARTY_NOTICES.md).

Thanks to the developers and communities behind these projects. Please report
issues with this repository here rather than to the upstream projects unless
you have confirmed that the problem also exists without these patches.

## License

The original scripts and documentation in this repository are available under
the [MIT License](LICENSE). Adapted or bundled third-party material remains
subject to its respective upstream license and attribution requirements. See
the third-party notices stored alongside the relevant patches.
