# Mafia: Definitive Edition — experimental static HDR on macOS

This patch is an offline, game-local adaptation of the
[RenoDX Mafia: Definitive Edition module](https://github.com/clshortfuse/renodx/tree/9b212edad4dde9bca2b823b1e045b712b1a8d854/src/games/mafiade).
It does not install RenoDX, ReShade, a DLL override, a Wine registry change, or
a custom Wine/CrossOver runtime.

> [!WARNING]
> The executable and shader-cache transformation is statically verified. The
> FP16/scRGB prototype launched, but its macOS screenshot decoded as SDR and
> therefore did not verify HDR presentation. The HDR10/PQ revision launches,
> and a temporary luminance diagnostic confirmed that its animated 3D menu
> scene produces pixels above the 203-nit paper white. End-to-end HDR metadata
> and the remaining visual paths are not yet fully validated. Keep both backups.

## Does Mafia DE support HDR?

The PC game does not expose a native HDR setting. RenoDX adds HDR by replacing
the game's final shaders and rendering through a floating-point backbuffer
proxy. This patch reproduces that design inside the game files, with fixed
settings, then converts the completed frame to HDR10/PQ for D3DMetal instead of
loading an injector at runtime.

The fixed profile uses:

- RenoDRT Reinhard tone mapping;
- 1,000-nit peak brightness;
- 203-nit game and UI paper white;
- gamma 2.2 correction;
- the upstream default color-grading and effects strengths;
- Mafia's vanilla film-grain path, because RenoDX's perceptual grain needs a
  new random seed from its live addon every frame.

There is no in-game HDR menu and no live RenoDX controls. Changing peak or
paper-white values requires rebuilding the static shader assets.

## Supported build

Only **GOG 1.0.3 v2** is accepted:

| File | Original SHA-256 |
| --- | --- |
| `mafiadefinitiveedition.exe` | `f063bf8ce27cee297abb6c374f383a922cf772f6984797fee9b4456986516abf` |
| `edit/shaders/shaders_binaries_[dx11].sc` | `b39eb3bca641020bd88ac27132f83d1d2ac4cdf521cc48565b5da9126317473f` |

The patch is DX11-only. Quit the game before applying or restoring it. An
HDR-capable display and CrossOver's D3DMetal backend are also required. The
current HDR10/PQ path is specifically targeted at D3DMetal and has not been
validated with DXMT.

## Install

Run the guided patcher from this directory:

```bash
./patch-hdr.sh
```

Choose **Apply**, then drag `mafiadefinitiveedition.exe` into Terminal. The
shader cache is found relative to that explicit executable path.

For unattended use:

```bash
./patch-hdr.sh --yes "/path/to/Mafia Definitive Edition/mafiadefinitiveedition.exe"
```

Read-only status check:

```bash
./patch-hdr.sh --check "/path/to/Mafia Definitive Edition/mafiadefinitiveedition.exe"
```

The patcher verifies both complete input hashes and every executable patch
site, stages both outputs on the destination filesystem, verifies their exact
output hashes, and only then replaces the installed files. Hash-suffixed
backups are never overwritten.

## Restore

Use the guided patcher, or run:

```bash
./patch-hdr.sh --restore --yes "/path/to/Mafia Definitive Edition/mafiadefinitiveedition.exe"
```

Restore only accepts files and backups owned by this patch. It refuses unknown
or later-modified files, and keeps the verified backups after restoration.

## What changes

- The executable requests an `R10G10B10A2_UNORM` swapchain, renders the game
  into a private `R16G16B16A16_FLOAT` texture, converts the completed linear
  frame from BT.709 to BT.2020 and ST.2084 PQ, and calls
  `IDXGISwapChain3::SetColorSpace1(12)` for HDR10 presentation.
- Eight shaders in the game's own DX11 cache are replaced with static RenoDX
  variants. All other 3,446 cached shaders and cache metadata are preserved.

See [technical details](TECHNICAL.md) for addresses, bytes, shader IDs,
provenance, and current validation status.

## Disclaimer

This patch modifies legally obtained game files for personal compatibility
use. It does not distribute the game executable or shader cache. It is an
independent community project and is not affiliated with or endorsed by 2K,
Hangar 13, CodeWeavers, Apple, GOG, or the RenoDX project. Use it at your own
risk.

## Credits

The HDR shaders and proxy-shader design are adapted from RenoDX under the MIT
License. See [third-party notices](THIRD_PARTY_NOTICES.md).
