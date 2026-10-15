# Frame generation and ray tracing — investigation

15 October 2026. The initial DLSS patch left frame generation and ray tracing
blocked. The investigation below identified two further gates. The user has now
tested the full patch and enabled all three features. Static analysis and
automated tests used executable copies; the user performed the in-game test.

## What blocks the options

Both paths use a shared renderer flag at virtual address `0x14405AEFA`.
Initialization looks up `wine_get_version` in `ntdll.dll`; finding it sets the
flag. Another condition can also set it. References to this flag appear in
other device and resource code, so clearing it globally would have a wider
scope than these two features.

### Frame generation

The support routine at `0x141B7D810` checks the flag first. If set, it clears
manager byte `+0x19` and returns false before asking Streamline whether frame
generation is supported.

Otherwise, it checks Streamline initialization and device registration, calls
`slIsFeatureSupported(1000, adapterInfo)` and queries frame-generation state.
The menu's `GetDLSSGSupported()` binding at `0x1422733E0` calls renderer vtable
`+0x128`, which resolves to `0x141BDFB00` and reads manager byte `+0x19`.

The menu disables `Virtual_DLSSG` when this result is false. Any later Streamline
requirements still need to pass. In the subsequent user test, the HUD reported
additional output frames with frame generation enabled.

### Ray tracing

The game queries Direct3D device features in `0x141ECF5A0`. These include native
16-bit shader operations and the reported ray-tracing tier. Other game flags
also affect the initial support result.

It then checks the shared flag. When set, it clears the ray-tracing support
byte at `0x14405AED8`, even if the preceding capability checks passed. It also
clears a related tier-dependent flag. The menu's `GetRTSupported()` binding at
`0x142273A00` reads that support byte directly; `IsRayTracingSupported()` at
`0x142273040` reads the same byte.

The queried structures were checked against Microsoft's definitions of
[D3D12 options 4](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ns-d3d12-d3d12_feature_data_d3d12_options4)
and [D3D12 options 5](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ns-d3d12-d3d12_feature_data_d3d12_options5).
This investigation did not capture D3DMetal's actual responses for this machine.

## Implemented changes

The Bash patcher includes both changes. They passed fixture and disposable
Steam-build tests, followed by the user's in-game test of the full patch.

The approach is to skip the shared flag check only in each feature's support
routine. The flag remains available to all other renderer code, and the normal
capability checks remain in place.

| Feature | File offset | Virtual address | Original | Candidate |
| --- | --- | --- | --- | --- |
| Frame generation | `0x1B7CE30` | `0x141B7D830` | `74 17` | `EB 17` |
| Ray tracing | `0x1ECEECD` | `0x141ECF8CD` | `0F 84 66 01 00 00` | `E9 67 01 00 00 90` |

The first change always jumps to `0x141B7D849`, where the existing Streamline
checks continue. The second always jumps to `0x141ECFA39`, where the existing
computed ray-tracing support and tier are checked. Neither writes a support
flag to true. Both replace complete instructions and preserve their original
fall-through boundaries, without adding hooks or changing the stack or ABI.

Expected hashes calculated in memory from the current DLSS-patched executable:

| Candidate | SHA-256 |
| --- | --- |
| DLSS + frame-generation gate | `9e998e797f24a0d9920c23c49abee26caaa8b7ecd07dca986baece56b90412b8` |
| DLSS + ray-tracing gate | `ae725f8fd574c36a55d2c56bdf301137b5a3d246d4831d4f5c23449e4e0e3257` |
| DLSS + both gates | `5dc266a88709f0bfe3573ef5f5e3d055dfcd6a5a698a8ab4aa390be34015e419` |

The base DLSS-patched hash is
`d8df34019c81abf04aedc256e7783fe88f93ad77dc27cf37c4c245d8e06a32ca`.
These offsets and hashes apply only to the supported build.

## In-game results

The user tested the full patch on 15 October 2026 with an M4 Pro, macOS 27.0,
CrossOver Preview `27.0.0.41069` and GPTK `4.0b3`. All three graphics options could
be enabled. The supplied screenshots show:

| State reported by the user | HUD output FPS | Render FPS | Rendering evidence |
| --- | --- | --- | --- |
| Baseline | 51.80 | 51.80 | MetalFX temporal upscaling, 1485×835 → 2560×1440 |
| Frame generation enabled | 71.67 | 31.32 | Separate output and render rates |
| Ray tracing enabled | 29.05 | 29.05 | Ray dispatches, BVH build/refit and acceleration encoders |

The frame-interpolator “Enabled” label can remain stale after disabling the
feature, so it is not used alone as evidence. The output/render counters provide
stronger evidence of frame generation; ray-tracing commands show that RT work
reaches the backend. Neither proves visual correctness throughout the game.

Frame generation reduced the base rendering rate in this scene and did not reach
the display's maximum refresh rate. The generation multiplier was not adjustable.
The saved DX12 configuration had VSync enabled and a 120 FPS limit; no controlled
VSync comparison has been performed, so the slowdown's cause remains unknown.
These HUD snapshots are not benchmark averages, and their counter ratio should
not be treated as an exact generated-frame multiplier. No pacing change is
included in this patch.

Static checks used Ghidra 12.1.4 and Apple LLVM 21.0.0 without launching the game.

## Remaining Wine checks

The other direct `wine_get_version` lookups were traced to their callers. They
are not additional confirmed graphics-feature blocks.

### NVIDIA API load retries

The detector at `0x14007C010` records whether Wine's export is present. Its caller
at `0x14007C0E0` loads `nvapi64.dll` and resolves `nvapi_QueryInterface` and
`nvapi_Direct_GetMethod` through `0x14007BE90`.

The loader returns an existing module if available. Otherwise, it checks the
Wine detector only after a prior DLL load failure has set `0x1457F4311`.
Under Wine, that combination returns `-2` without another load attempt. A first
load attempt is still allowed; a successful load follows the ordinary NVAPI
setup. This is a failed-load retry guard, not a blanket NVAPI-disable check.

The module and export names were checked in the executable's string data.
The DLL-loader wrapper is called at `0x14007C23E`; many NVAPI wrappers use it.
There is no evidence that removing this retry guard would unlock another menu
option. Leave it unchanged.

### Explicit NVIDIA API loading

The helper at `0x1427FA290` returns whether `wine_get_version` exists. Its direct
caller at `0x141B788F9`, after Streamline manager construction, loads
`nvapi64.dll` when the helper returns true. This is Wine-specific setup worth
preserving. It is separate from the earlier branch that skipped constructing
Streamline.

### Steam Deck thread affinity

The selector at `0x1427FB020` checks Wine and the platform value stored at
`0x145C91DE0`. For platform values `12` and `13`, it can return affinity masks
`0x3` and `0xC`; otherwise it returns zero. Both values map to the literal string
`steamdeck` in the platform-name function at `0x1427FA110`. Value `14` maps to
`steammachine`, but is outside this selector's special case. No particular Steam
Deck model was inferred from the two IDs.

The masks are consumed by thread setup/teardown code:

| Caller | Observed use |
| --- | --- |
| `0x141C69590` | Thread setup, priority and affinity selection. |
| `0x1427FAC10` | Passes the selected mask to `SetThreadAffinityMask`. |
| `0x1427FB280` | Uses both selector results before setting thread affinity. |
| `0x141CD9A67`, `0x141CD9BC5` | Additional selector call sites in thread-related code; not fully decompiled. |

On the inspected callers' paths, `0x3` selects logical processor bits 0 and 1;
`0xC` selects bits 2 and 3. This does not identify macOS performance/efficiency
cores. The actual platform ID and effective affinity on the user's Mac were not
captured. No performance benefit from changing this logic has been established.
Leave these scheduling choices unchanged.

### Scope of the search

The executable contains two ASCII instances of `wine_get_version`, referenced by
five functions: the Streamline initialization gate, shared renderer flag setup,
NVAPI retry detector, explicit NVAPI-loading helper and Steam Deck selector.
The selector contains two lookups on different paths. A string scan found no
additional `wine_*` export names. This is an inventory of those direct lookups,
not a claim that every Wine-dependent path in the game or bundled DLLs has been
audited.

These findings used the same Ghidra and LLVM tools as above, with no game launch.
For example:

```bash
xcrun llvm-objdump -d --start-address=0x14007c010 --stop-address=0x14007c1d5 "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x1427fb020 --stop-address=0x1427fb0da "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x1427fac10 --stop-address=0x1427fadf0 "/path/to/bin/x64_dx12/witcher3.exe"
```
