# Witcher 3 DLSS patch — technical notes

The patch removes one Wine detection branch from the DX12 executable. It allows
Streamline initialization while keeping the library's device and feature checks.
It does not force the DLSS support flag to true.

Analysis date: 14 October 2026. Patched in-game behavior is untested.

## Supported build

The supplied Steam manifest reports build **25773555**. The in-game version label
is unknown. The investigated environment was CrossOver Preview `27.0.0.41069`
with D3DMetal `4.0b3`, with D3DMetal and DLSS enabled in the Steam bottle.

| Executable state | SHA-256 |
| --- | --- |
| Original | `2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101` |
| Patched | `d8df34019c81abf04aedc256e7783fe88f93ad77dc27cf37c4c245d8e06a32ca` |

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
| `0x1B77ECB` | `0x141B788CB` | `75 42` — conditional jump | `90 90` — two NOPs |

The original jump skips to `0x141B7890F` when Wine is detected. Removing it lets
execution continue into the existing allocation and constructor path. The
preceding instruction starts at `0x141B788C8`; the following instruction starts
at `0x141B788CD`. Instruction boundaries were checked with LLVM disassembly.

The replacement covers one complete instruction. It adds no hook or code cave
and makes no stack, register or calling-convention changes.

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

Allowing initialization may expose a later Streamline failure. No FPS gain,
image-quality improvement or working DLSS rendering has been established.

## Frame generation

A separate Wine lookup at `0x141EE5620` sets the flag at `0x14405AEFA`.
The frame-generation support routine at `0x141B7D810` checks that flag and returns
false when it is set. This patch leaves that path unchanged. Other uses of the
flag have not been fully audited.

## File operations

The patcher requires Python 3.9+, Bash and macOS `ps`. It uses no network access
or additional payloads. The caller supplies a game folder or DX12 executable.
Check and dry-run modes do not write files.

Before applying or restoring, it checks for a running Witcher 3 process. If the
process check fails, it stops. It also refuses executable symlinks, hard links,
unknown hashes, unexpected patch bytes and conflicting backups.

Apply saves a verified original as
`witcher3.exe.pre-dlss-wine-gate.2df765398a3d`. Existing backups are never
overwritten. The output is staged in the executable's folder and its full hash
is verified. The input is checked again before atomic replacement. File mode,
ownership, timestamps and extended attributes are preserved where supported;
metadata failures stop installation.

Restore requires the exact patched hash and a verified original backup. Later
unrelated edits are refused. Both repeated apply and repeated restore are safe;
backups are kept. An update can replace the executable and remove the patch.

## Interruption recovery

Ordinary errors and Ctrl-C remove the patcher's temporary stage and lock. A crash,
SIGKILL or power loss can leave these files beside the executable:

- `.witcher3-dlss-stage-*` — a staged copy;
- `witcher3.exe.dlss-wine-gate.lock` — an operation lock containing the patcher PID;
- an incomplete backup.

1. Confirm that the game and patcher are closed. Do not remove an active lock.
2. Run `--check`. It verifies the executable and any backup.
3. If an abandoned lock or partial backup blocks recovery, preserve it outside
   the game folder after verifying that it belongs to the interrupted operation.
4. Run `--check` again before applying or restoring.

A valid original backup can be reused. If the executable has an unknown hash,
recover it through Steam and keep conflicting files for inspection. Do not force
the patch onto it. Atomic replacement does not guarantee survival through power
loss on every filesystem.

## Validation

| Check | Result |
| --- | --- |
| Static analysis | Wine branch, support flags and menu path traced; disassembly cross-checked. |
| Synthetic fixtures | Eight tests passed, covering repeat apply/restore, read-only modes, unsupported inputs, symlinks, backup and lock conflicts, output verification, changed inputs, later edits, install failure, interruption and process checks. |
| Supported executable | Apply/repeat apply and restore/repeat restore passed on a disposable copy. Exactly two bytes changed; both full hashes matched. |
| Paths and invocation | Spaces, Unicode and invocation from another directory tested. |
| In-game with patch | Not run. |

The installed executable remained unchanged. Proprietary test copies were removed
and are not stored in the repository.

Run the fixture tests and shell syntax check from this folder:

```bash
python3 test_patch_dlss.py
bash -n patch-dlss.sh
```

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
