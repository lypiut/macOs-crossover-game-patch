# DMC5 HDR patch — technical details

This document records the evidence needed to review or migrate the binary
patch. File offsets are offsets in `DevilMayCry5.exe`; virtual addresses use
the PE image base `0x140000000`.

## Supported executables

| Steam build | State | SHA-256 |
| --- | --- | --- |
| `24901913` | Original | `5523cb79fe13858335e893ca7ed98b4021a96b8cec92940058cb5d58d09d4169` |
| `24901913` | Patched | `ce87ab19457bd062e71884d318579c6fac77b63c4b8435d1e7cbda91fa71f4a1` |

Steam build `24901913` was published on 24 September 2026. It replaced the
executable and added Capcom's `re_chunk_000.pak.patch_008.pak`. The HDR shader
archive therefore moved unchanged to slot `009`; its SHA-256 remains
`4c1c31e8a54c41ab9ba811d262345f75bde693b7be828afa4d7a66c45159341d`.

## Why the patch is needed

DMC5 has native HDR rendering and presentation paths. Its DX12 HDR service
contains the NVAPI IDs `0x84F2A8DF` (HDR capability) and `0x351DA224`
(display colour control), but its adapter-vendor selection chooses a null HDR
service under CrossOver. Failed service calls stop the normal transition.

The patch enables the existing transition. On DX12 it also calls
`IDXGISwapChain3::SetColorSpace1(12)` after successful swapchain creation.
Value `12` is `DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020` (HDR10/PQ), which
D3DMetal presents through Apple's PQ colour space with extended dynamic range.

The September 2026 executable keeps the same logic. Static comparison found
the corresponding functions after a compiler/layout change; renderer fields
used by this path moved by `0x10`.

## September 2026 patch sites

The `.text` section maps file offsets with a `+0xC00` VA delta. The `.rdata`
code-cave area maps with a `+0x1600` VA delta.

| Purpose | File offset | Virtual address | Original bytes | Replacement |
| --- | ---: | ---: | --- | --- |
| DX11 HDR gate | `0x02B65C80` | `0x142B66880` | `0F 84 A4 03 00 00` | six NOPs |
| DX12 HDR-state hook | `0x02B58442` | `0x142B59042` | `41 3A 80 C7 B3 30 00` | branch to state stub + two NOPs |
| DX12 enable result 1 | `0x02B58C53` | `0x142B59853` | `74 7F` | two NOPs |
| DX12 enable result 2 | `0x02B58C71` | `0x142B59871` | `74 61` | two NOPs |
| DX12 PQ hook | `0x02B4D921` | `0x142B4E521` | `0F 57 C0 4C 89 4D 30` | branch to PQ stub + two NOPs |
| PQ stub | `0x04B9CE22` | `0x144B9E422` | `CC` padding | null-check swapchain, call vtable `+0x130` with value `12`, replay displaced instructions, return |
| HDR-state stub | `0x04B9CE46` | `0x144B9E446` | `CC` padding | set desired HDR byte, replay comparison, return with flags intact |
| `.rdata` flags | `0x02CC` | PE header | `40 00 00 40` | `40 00 00 60` (add execute permission) |

Both stubs use Microsoft x64 volatile registers only, preserve the caller's
stack frame, replay every displaced instruction, and return at instruction
boundaries. The PQ stub uses the swapchain pointer already stored at
`[rsp+0x50]`; no D3DMetal or NVAPI implementation is replaced.

## Shader provenance

The two replacements are adapted from RenoDX snapshot
[`fb7183192b47417934e21b970b054e82080d20b6`](https://github.com/clshortfuse/renodx/tree/fb7183192b47417934e21b970b054e82080d20b6/src/games/dmc5):

- `HDRPostProcess_WithTonemap_0xA59B718D.ps_5_0.hlsl`;
- `ConvertRec2020PS_0x6AB2B106.ps_5_0.hlsl`.

The archive embeds the compiled replacements in game-owned SDF containers. It
cannot be reproduced without legally obtained DMC5 data files. The runtime
patch does not load RenoDX, ReShade, or REFramework.

## Validation

Steam build `24901913` was tested with both DX11 and DX12 on an Apple M4 Pro,
macOS 27.0, CrossOver Preview `20260821` (`27.0.0.40921`), and D3DMetal. The
game launched normally and HDR activated in both backends.

The following checks are also complete:

- byte-level mapping and disassembly of every new patch site;
- patched-output SHA-256 verification;
- apply, repeated apply, check, restore, repeated restore, unsupported input,
  backup and shader conflicts, old-backup preservation, symlink rejection, and
  spaces and Unicode in paths;
- confirmation that restore reproduces the new original executable hash and
  does not alter Capcom's slot `008` archive.
