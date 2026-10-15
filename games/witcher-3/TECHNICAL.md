# Witcher 3 CrossOver graphics patch — technical notes

The patch changes three instructions in the DX12 executable: Streamline
initialization, the frame-generation support gate and the ray-tracing support
gate. Normal device and feature checks remain in place. It does not write the
support flags to true or clear the shared renderer compatibility flag.

Analysis began on 14 October 2026. On 15 October, the user tested the full patch
and reported that DLSS, frame generation and ray tracing could all be enabled.
Screenshots show additional output frames and ray-tracing commands; see
[the investigation and test results](FEATURE_GATES.md).

## Supported build

The supplied Steam manifest reports build **25773555**. The in-game version label
is unknown. The investigated environment was CrossOver Preview `27.0.0.41069`
with D3DMetal `4.0b3`, with D3DMetal and DLSS enabled in the Steam bottle.

| Executable state | SHA-256 |
| --- | --- |
| Original | `2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101` |
| Full patch | `5dc266a88709f0bfe3573ef5f5e3d055dfcd6a5a698a8ab4aa390be34015e419` |

These identities apply to `bin/x64_dx12/witcher3.exe`. No other executable is
supported. File offsets must be verified again for any new build.

## Why the menu rejects DLSS

The game looks for `wine_get_version` in `ntdll.dll`. It checks whether that
export exists; it does not call it or compare Wine versions. When the export is
present, the game skips creating its Streamline manager.

CrossOver's supplied `ntdll.dll` exports `wine_get_version` at RVA `0x811a0`.
The earlier unpatched launch loaded `sl.interposer.dll`, but the module trace
showed no Streamline feature plugins loading. This agrees with the static trace,
though the branch was not observed in a debugger during that launch.

The menu uses `GetIsDLSSSupported()`, which returns false when the Streamline
manager is absent. Two game scripts connect that result to the menu:

- `content/content0/scripts/game/gui/main_menu/ingamemenu/igmOptions.ws:450`
  locks the DLSS selection.
- `content/content0/scripts/game/gui/main_menu/ingameMenu.ws:1557` passes support
  to the Flash menu; line `1837` displays `option_warning_dlss_support` after a
  rejected selection.

The missing manager is an earlier blocker than GPU or driver checks. A missing
Streamline log alone should therefore not be described as a failed `slInit` call.

## Exact change

Virtual addresses below use the PE image base `0x140000000`.

| File offset | Virtual address | Original bytes | Replacement |
| --- | --- | --- | --- |
| `0x1B77ECB` | `0x141B788CB` | `75 42` | `90 90` |
| `0x1B7CE30` | `0x141B7D830` | `74 17` | `EB 17` |
| `0x1ECEECD` | `0x141ECF8CD` | `0F 84 66 01 00 00` | `E9 67 01 00 00 90` |

The original jump skips to `0x141B7890F` when Wine is detected. Removing it lets
execution continue into the existing allocation and constructor path. The
preceding instruction starts at `0x141B788C8`; the following instruction starts
at `0x141B788CD`. Instruction boundaries were checked with LLVM disassembly.

Each replacement covers a complete instruction. There is no hook, code cave,
stack or calling-convention change. The frame-generation jump reaches
`0x141B7D849`; the ray-tracing jump reaches `0x141ECFA39`. Both targets and the
full output hash were verified on a disposable executable copy. Eight byte
values change across the three instruction sites.

## Support checks after initialization

| Step | Game virtual address | Result |
| --- | --- | --- |
| Create Streamline manager | `0x141B831D0` | Calls `slInit`; success is stored at manager `+0x16`. |
| Register graphics device | `0x141ED7E70` | Calls `slSetD3DDevice`; success is stored at `+0x17`. |
| Refresh feature support | `0x141B82DB0` | Checks both flags, then calls `slIsFeatureSupported(0, adapterInfo)` for DLSS upscaling. A zero result sets `+0x18`. |
| Read menu support | `0x141BE0090` | Returns false if the manager is missing or `+0x18` is zero. |

The manager pointer is stored at `0x145857E48`. The renderer accesses it through
`0x141BDFFE0`; the script binding is at `0x141F3C500`. Adapter information includes
an eight-byte DXGI adapter LUID when available.

Normal Streamline initialization and device checks still run. The user reported
working DLSS. No controlled DLSS image-quality or performance comparison was
made; the in-game frame-generation observations are recorded separately below.

## Frame generation

A separate Wine lookup at `0x141EE5620` sets the flag at `0x14405AEFA`.
The frame-generation support routine at `0x141B7D810` checks that flag and returns
false when it is set. The patch bypasses this early return only in the
frame-generation routine. It similarly skips the ray-tracing override while
retaining the computed device capabilities. Other users of the shared flag,
including resource and device code, are unchanged; see [FEATURE_GATES.md](FEATURE_GATES.md).

## File operations

The patcher uses macOS Bash 3.2 and bundled utilities, including `shasum`, `od`,
`dd`, `cp`, `stat`, `mktemp`, `mv` and `ps`. It requires no Python, network access
or payload. Supplying a game folder or DX12 executable applies the full patch;
`--restore` restores the original. `--help` prints usage. There are no profiles,
check or dry-run options. Supplying a path is the explicit apply request.

Before applying or restoring, it checks for a running Witcher 3 process. If the
process check fails, it stops. It also refuses executable symlinks, hard links,
unknown hashes, unexpected patch bytes and conflicting backups.

Apply saves a verified original as
`witcher3.exe.pre-dlss-wine-gate.2df765398a3d`. Existing backups are never
overwritten. The output is staged in the executable's folder and its full hash
is verified. The input is checked again before atomic replacement. File mode,
ownership, timestamps and extended attributes are preserved where supported;
metadata failures stop installation.

Only the original and full-patch hashes are accepted. Restore requires the
exact full-patch hash and a verified original backup. Later
unrelated edits are refused. Both repeated apply and repeated restore are safe;
backups are kept. An update can replace the executable and remove the patch.

## Interruption recovery

Ordinary errors and Ctrl-C remove the patcher's temporary stage and lock. A crash,
SIGKILL or power loss can leave these files beside the executable:

- `witcher3.exe.tmp.*` — a staged copy;
- `witcher3.exe.dlss-wine-gate.lock/` — a lock directory containing a `pid` file;
- an incomplete backup.

1. Confirm that the game and patcher are closed. Do not remove an active lock.
2. Preserve the files for inspection and compare the executable and backup hashes
   with the supported hashes above.
3. If an abandoned lock or partial backup blocks recovery, preserve it outside
   the game folder after verifying that it belongs to the interrupted operation.
4. Apply or restore again. The script revalidates the executable and backup.

A valid original backup can be reused. If the executable has an unknown hash,
recover it through Steam and keep conflicting files for inspection. Do not force
the patch onto it. Atomic replacement does not guarantee survival through power
loss on every filesystem.

## Validation

Validation runs on 15 October 2026 used temporary harnesses outside the repository.
No test scripts or proprietary fixtures are distributed. The final fixture rerun
mocked process enumeration only in disposable fixture scripts because the game
was running; production process checks were left intact. Supported-build partial
patch rejection was checked with the unmodified production script.

- Eleven Bash fixture tests passed: apply/repeat apply, restore/repeat restore,
  rejection of partial patches and unsupported inputs, backup
  conflicts, symlinks/hard links, existing locks, corrupt staged output,
  concurrent input changes, later edits, failed installation, failed backup copy
  and signal cleanup.
- Six process-check fixtures passed: no game, direct game process, Wine loader
  with the game argument, another Wine app, the calling shell and failed `ps`.
- On a disposable Steam-build copy, original → full patch → original passed
  with exact expected hashes, including repeated operations. A partial patch
  was refused for both apply and restore, leaving the files unchanged.
- LLVM disassembly confirmed both new branch targets. Eight changed byte values
  matched the three planned sites. An extended attribute and executable mode
  were preserved. Paths with spaces/Unicode and invocation from another working
  directory passed.
- Bash syntax and Git whitespace checks passed.
- In-game user testing of the full patch on an M4 Pro with macOS 27.0 confirmed
  that DLSS, frame generation and ray tracing can be enabled. Screenshots show
  51.80 output/render FPS in the reported baseline and 71.67 output / 31.32
  render FPS with frame generation. A ray-tracing screenshot shows 29.05 FPS,
  ray dispatches and acceleration-structure work. These are individual HUD
  readings, not benchmark averages or proof of visual correctness.
- The generation multiplier was not adjustable. Frame-generation slowdown and
  refresh-rate behavior remain unresolved; no further pacing patch is included.

The installed executable and its original backup remained unchanged during
the automated validation; the user applied the patch for the in-game test. Owned temporary game copies were removed.

[Automatic DLSS and dynamic-resolution tracing](DYNAMIC_RESOLUTION.md) records
why Automatic selects a fixed preset and why dynamic scaling needs further work.

## Reproducing the analysis

Tools: Ghidra **12.1.4** and Apple LLVM **21.0.0**. Ghidra used the Windows x86-64
PE loader with targeted decompilation. Some inferred prototypes and split function
boundaries were imperfect, so the branch, strings, imports and flag writes were
checked against disassembly.

```bash
xcrun llvm-objdump -d --start-address=0x141b788a3 --stop-address=0x141b7890f "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141be0090 --stop-address=0x141be00c9 "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -p "/path/to/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/x86_64-windows/ntdll.dll"
shasum -a 256 "/path/to/bin/x64_dx12/witcher3.exe"
```

Only original patcher code and research notes are distributed. This work is
unaffiliated with CD PROJEKT RED, CodeWeavers, Apple or NVIDIA. The repository's
MIT license applies to the original patcher code.
