# Mafia: Definitive Edition static HDR patch — technical details

This document separates static evidence, observed in-game behavior, and checks
that remain incomplete. File offsets apply only to GOG 1.0.3 v2.

## Supported and generated files

| File | State | Size | SHA-256 |
| --- | --- | ---: | --- |
| `mafiadefinitiveedition.exe` | original | `111434896` | `f063bf8ce27cee297abb6c374f383a922cf772f6984797fee9b4456986516abf` |
| `mafiadefinitiveedition.exe` | patched | `111439360` | `fc0cbcce2b4aaca344f9a2b1566f371aa9a32831a7ef2e6f3aeddab86c823429` |
| `shaders_binaries_[dx11].sc` | original | `19602354` | `b39eb3bca641020bd88ac27132f83d1d2ac4cdf521cc48565b5da9126317473f` |
| `shaders_binaries_[dx11].sc` | patched | `19767922` | `6ef65ce9259d2f2e40d6a1a58264b1932727e8082d1fe684e6aacb4d131f05bb` |

The PE image base is `0x140000000`. Its `.text` section maps a virtual address
to a file offset by subtracting `0x140000A00`.

## Executable design

The original game creates an `R8G8B8A8_UNORM` DX11 swapchain. It obtains the
real backbuffer, creates UNORM and sRGB views, renders into it, and later calls
`IDXGISwapChain::Present`.

The patch changes the real swapchain format to `R10G10B10A2_UNORM`. Its
backbuffer hook keeps an RTV for the real swapchain texture and gives the game
a separate `R16G16B16A16_FLOAT` proxy texture. The game's existing view and
resource-wrapper code then operates on that proxy. Immediately before Present,
the hook draws a fullscreen triangle through a static finalization shader. The
shader converts the linear BT.709 result to BT.2020, encodes it with ST.2084
PQ, writes it into the real backbuffer, and unbinds its SRV before calling the
original Present method.

The hook also queries `IDXGISwapChain3` and requests
`DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020` (`12`), the DXGI HDR10/PQ color
space. Static inspection of the installed D3DMetal 3.0 implementation confirms
that it accepts value `12` and maps it to `kCGColorSpaceITUR_2100_PQ`.

### Patch sites

| Purpose | File offset | Virtual address | Original | Replacement |
| --- | ---: | ---: | --- | --- |
| Swapchain format | `0x03B17DE8` | `0x143B187E8` | `C7 45 C0 1C 00 00 00` | format `24` (`R10G10B10A2_UNORM`) |
| Backbuffer creation detour | `0x03B17BB1` | `0x143B185B1` | 43-byte GetBuffer block | save original state, call `.hdr+0x000`, return at `0x143B185DC` |
| Proxy RTV 1 format | `0x03B17BF8` | `0x143B185F8` | format `28` | format `10` |
| Proxy RTV 2 format | `0x03B17C1F` | `0x143B1861F` | format `29` | format `10` |
| Proxy SRV format | `0x03B17C52` | `0x143B18652` | format `28` | format `10` |
| Engine wrapper format | `0x03B17CB3` | `0x143B186B3` | `E_PF_A8R8G8B8` (`0x15`) | `E_PF_A16B16G16R16F` (`0x20`) |
| Resize cleanup detour | `0x03B0803A` | `0x143B08A3A` | 14-byte epilogue block | jump to `.hdr+0xF60` trampoline |
| Present detour | `0x03B1BF4D` | `0x143B1C94D` | 14-byte Present block | call `.hdr+0x2F0` |

A new `.hdr` PE section is installed at RVA `0x07039000`, file offset
`0x06A45E00`, with virtual size `0xF78`, raw size `0x1000`, and executable,
readable, writable characteristics. Code and mutable COM pointers currently
share this small section. The patch raises `SizeOfImage` to `0x0703A000`, clears
the PE checksum, and clears the Authenticode security-directory entry because
modifying the executable invalidates its original signature. The original
certificate bytes remain as inert padding and are not distributed.

The payload uses Microsoft x64 calling conventions. Detours preserve the
nonvolatile registers they displace, land on decoded instruction boundaries,
and replay displaced cleanup instructions in the trampoline. The executable
does not enable Control Flow Guard.

## Shader-cache replacements

The game cache contains 3,454 sequential DXBC records. Each record has an
18-byte header whose final little-endian word is the DXBC size. The builder
checks the entire original cache hash, the original shader CRC32, the DXBC
container size, and the record size before replacing a shader.

| Shader | RenoDX CRC32 | Original DXBC offset | Original size | Static size |
| --- | ---: | ---: | ---: | ---: |
| videos 2 | `00D96EAE` | `0x004ACA12` | `444` | `424` |
| low-health effect | `D980FA68` | `0x004D3286` | `2420` | `4472` |
| fireworks | `ACD34CE7` | `0x0094BD00` | `6344` | `9276` |
| loading screen | `747C6210` | `0x00B83540` | `896` | `1068` |
| depth of field 7 | `3EB9D976` | `0x00CBD744` | `1364` | `3416` |
| videos | `A7799306` | `0x00E21DE0` | `1004` | `37708` |
| post-process effect | `D47322A6` | `0x00EAAD20` | `2772` | `4828` |
| tone map | `916B1D65` | `0x00FEB00C` | `9704` | `129324` |

The replacements come from RenoDX revision
`9b212edad4dde9bca2b823b1e045b712b1a8d854`, cross-checked against the pinned
official release asset `nightly-20260922/renodx-mafiade.addon64` with SHA-256
`079f50a6bee9052899e18d77ef5308318e4003fbe4ee9ad1acbfcd442ab695d7`.
Resource declarations prove the embedded-blob mapping: ten-texture/three-sampler
tone map, four-texture videos, nine-texture/three-sampler fireworks, and the
remaining distinct signatures all match their named HLSL sources.

RenoDX normally supplies `ShaderInjectData` through constant buffer `b13`.
Every live `b13` read was replaced in DXBC assembly with the corresponding
fixed default literal, then each container was reassembled and disassembled
again to prove no live read remained. `videos2` never reads `b13`. The static
profile sets `hasLoadedTitleMenu=1` and `is_swapchain_write=1`; this assumes the
identified tone-map shader is used for the final swapchain-target pass, as in
the analyzed build.

## Bundled assets

`assets/mafiade-hdr-assets.tar.gz.b64` contains only the new PE section and the
eight replacement DXBC containers. It does not contain bytes from the original
game executable or cache. The patcher decodes and verifies the archive before
use; decoded archive SHA-256:

`93546dad0c22f65811e156baeb5a6b1523487b54ce17e44ee0d25186f73f1fdd`

The payload source is in `src/mafiade_hdr_payload.c`. The proxy shaders and
replacement shaders derive from the RenoDX sources identified above. Exact
compiled-asset hashes are also embedded in `patch-hdr.sh`.

## Validation status

Completed static and disposable-fixture checks:

- Ghidra control-flow and instruction-boundary review of each hook;
- PE section layout, relative branch target, COM vtable index, and x64 ABI
  review;
- disassembly of the final proxy shaders and all eight static replacements;
- structural re-parse of all 3,454 rebuilt cache DXBC records;
- exact patched-output hash verification;
- apply, repeated apply, check, restore, and repeated restore on disposable
  copies, including paths containing spaces;
- `bash -n` and `git diff --check`.

The first in-game launch of an earlier prototype stopped in Metal validation
because the engine wrapper still described the FP16 proxy as `A8R8G8B8` and
requested an incompatible `MTLPixelFormatRGBA8Unorm` view. The observed
assertion directly identified the missing descriptor. Adding the verified
`0x15` to `0x20` engine-format change documented above fixed that launch. The
subsequent FP16/scRGB build ran in game, but a macOS HDR HEIC capture decoded
with content headroom `1.0`. That capture did not verify HDR presentation; a
standard screenshot may flatten HDR content, so it does not establish whether
the live scRGB output was HDR or SDR.

The current build replaces only the final presentation path with the HDR10/PQ
path described above. It launched successfully through CrossOver and D3DMetal
on 2026-09-30. A temporary final-pass diagnostic replaced any pixel whose
linear BT.709 RGB maximum exceeded 210 nits with 1,000-nit green. The user
observed that marker in the animated 3D main-menu scene, confirming that the
static RenoDX tone-map path produces scene values above the 203-nit paper
white. The normal PQ executable was then restored and its hash reverified.

That diagnostic verifies highlight values at the input to the final BT.2020/PQ
conversion. It does not by itself prove the display's received luminance or
that macOS honored the requested DXGI color space. The attached HEIC used a
gain-map container, but its SDR rendition did not preserve the diagnostic
color; no reliable end-to-end luminance measurement was made. CrossOver and
macOS version numbers for this run remain unknown.

Not yet completed:

- resize, fullscreen/windowed transition, and quit/relaunch behavior;
- confirmation that macOS and D3DMetal honor `SetColorSpace1(12)` and present
  the PQ signal end to end;
- HDR capture/metadata and highlight-luminance validation;
- cutscene, loading-screen, low-health, depth-of-field, and fireworks visual
  checks.

Until those checks pass, successful launch alone must not be treated as proof
that HDR is correct.
