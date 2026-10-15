# Automatic DLSS quality and dynamic resolution

Read-only trace, 15 October 2026. This investigation does not add a patch.
The game was not launched and no installed files were changed.

## What Automatic does

Witcher 3 resolves Automatic into a fixed quality mode before the request reaches
GPTK. It does not use that option to maintain a target frame rate.

| Game setting | Streamline DLSS mode |
| --- | --- |
| Automatic (`0`), output height below 2160 | Quality (`3`) |
| Automatic (`0`), output height 2160 or greater | Performance (`1`) |
| Quality (`1`) | Quality (`3`) |
| Balanced (`2`) | Balanced (`2`) |
| Performance (`3`) | Performance (`1`) |
| Ultra Performance (`4`) | Ultra Performance (`4`) |
| DLAA (`5`) | DLAA (`6`) |

At 2560×1440, Automatic therefore requests Quality. This is a game decision;
GPTK does not receive the game's Automatic value as a separate upscaling mode.
The [Streamline header](https://github.com/NVIDIA-RTX/Streamline/blob/main/include/sl_dlss.h)
defines the mode values and optimal-settings structure.

## Trace evidence

Build: Steam **25773555**, `bin/x64_dx12/witcher3.exe`. Original SHA-256:
`2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101`.
The installed executable inspected here has the full graphics-patch hash:
`5dc266a88709f0bfe3573ef5f5e3d055dfcd6a5a698a8ab4aa390be34015e419`.
The three existing compatibility patches do not alter these functions.
CrossOver Preview `27.0.0.41069`, GPTK `4.0b3`; user test hardware M4 Pro,
macOS 27.0. Tools: Ghidra 12.1.4 and Apple LLVM 21.0.0.

All addresses below are virtual addresses using image base `0x140000000`.
These are analysis locations, not proposed patch sites.

- The menu XML maps Automatic to `PostProcess/DLSSQuality=0`. The configuration
  record at `0x145151438` points to the `DLSSQuality` string and its value at
  `0x145151458`.
- The selector at `0x1403206C0` (file offset `0x31FCC0`) maps game values to
  Streamline modes. For zero, it compares its second argument with `0x870`
  (2160) at `0x1403206EC`. Below that threshold it re-enters the jump table at
  game mode 1 (Quality); otherwise at game mode 3 (Performance). This second
  jump-table lookup matters: its intermediate index is not the returned mode.
- The dimension setup at `0x141BF0680` passes the width/height pair through
  `0x141EA4280` into `0x14512F3C4` / `0x14512F3C8`. The selector's callers use
  the second dimension, output height. The DLSS execution path also calls the
  selector at `0x141B7E786`, passing its output-height field at `+0xBE8`.
- The resolution wrapper at `0x141ECC550` (file offset `0x1ECBB50`) selects the
  DLSS path when the antialiasing selector at `0x14512F3EC` equals 6. It calls
  the quality selector, then `0x141ED7D10` with output width, output height and
  the resolved Streamline mode.
- `0x141ED7D10` (file offset `0x1ED7310`) resolves
  `slDLSSGetOptimalSettings` through `slGetFeatureFunction`. It builds
  `DLSSOptions` version 3 and `DLSSOptimalSettings` version 1. On success it
  copies only `optimalRenderWidth` / `optimalRenderHeight` into the requested
  rendering dimensions. It does not use the returned dynamic min/max sizes.

The Automatic selector contains no frame-time measurement or target-FPS input.
Ghidra split some Windows unwind regions and did not fully recover the second
jump table; LLVM instructions and the raw jump-table entries were checked to
establish the mapping above.

## Why unlocking the DRS menu is insufficient

The existing Dynamic Resolution Scaling (DRS) path has three separate obstacles:

1. `bin/config/r4game/user_config_matrix/pc/graphics.xml` marks
   `Virtual_DynamicResolutionScaling` with `disableIfDLSS`, `disableIfDLSSG`
   and `disableIfXESS`. `ingameMenu.ws`, in
   `updateDynamicResolutionScalingEnabledOption()`, independently disables the
   option for those features.
2. The resolution controller at `0x141EA5A60` branches into fixed DLSS mode/index
   selection when the antialiasing selector is 6. The comparison is at
   `0x141EA5AB3` (file offset `0x1EA50B3`). This path reaches
   `0x141EA5260` without entering the ordinary frame-time-driven DRS logic.
3. The resolution application function at `0x141EA5260` calls `0x141ECC550`.
   With DLSS selected, that wrapper obtains the fixed optimal dimensions above
   and reports the request handled. The ordinary variable-dimension calculation
   is skipped even if the DRS index changes.

This explains why changing only Automatic or removing the menu restriction
would not implement dynamic DLSS resolution.

## What remains to establish

MetalFX supports dynamically sized input, but this trace does not establish
whether GPTK's NGX replacement exposes and correctly forwards that capability.
See [Apple's dynamic-resolution explanation](https://developer.apple.com/videos/play/wwdc2025/211/).

A working extension would need to let the existing controller select dimensions
within a supported range and preserve them through the DLSS path. The runtime
must receive matching color/depth/motion extents and jitter information. Its
handling of changing sizes and frame interpolation must be checked before
proposing binary changes. No safe replacement bytes or working dynamic-resolution
patch have been established by this investigation.

## Reproduce the static checks

```bash
xcrun llvm-objdump -d --start-address=0x1403206c0 --stop-address=0x140320740 "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141ecc550 --stop-address=0x141ecc645 "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141ed7d10 --stop-address=0x141ed7e5f "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141ea5a60 --stop-address=0x141ea5b85 "/path/to/bin/x64_dx12/witcher3.exe"
```

No game binaries, decompiled game source or test fixtures are distributed.
