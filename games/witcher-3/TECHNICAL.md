# Witcher 3 — technical reference

For installation and removal, use the [README](README.md).

## What changes

The game detects Wine and blocks three graphics features. The patch allows
DLSS initialization, bypasses the frame-generation rejection and prevents the
ray-tracing support result from being cleared. Normal device and feature checks
still run. NVAPI setup, resource handling and thread scheduling are unchanged.

Only `bin/x64_dx12/witcher3.exe` from **Steam build 25773555** is supported.
Testing used CrossOver Preview `27.0.0.41069`, GPTK `4.0b3` and macOS `27.0`.
The in-game version label was not recorded.

| File state | SHA-256 |
| --- | --- |
| Original | `2df765398a3d1f165db418271be7200178320a4466817379f2fa0dc0001fb101` |
| Patched | `5dc266a88709f0bfe3573ef5f5e3d055dfcd6a5a698a8ab4aa390be34015e419` |

## Exact changes

File offsets refer to positions in the executable. Virtual addresses use image
base `0x140000000` and are provided for disassembly.

| Feature | File offset | Virtual address | Original bytes | Replacement bytes |
| --- | --- | --- | --- | --- |
| DLSS initialization | `0x1B77ECB` | `0x141B788CB` | `75 42` | `90 90` |
| Frame generation | `0x1B7CE30` | `0x141B7D830` | `74 17` | `EB 17` |
| Ray tracing | `0x1ECEECD` | `0x141ECF8CD` | `0F 84 66 01 00 00` | `E9 67 01 00 00 90` |

Each replacement covers one complete instruction; eight byte values change in
total. There are no added hooks or stack changes. The first replacement lets
Streamline initialize instead of jumping to `0x141B7890F`. The other two jump
to `0x141B7D849` and `0x141ECFA39`, retaining the existing capability checks.
The shared Wine compatibility flag is not cleared globally.

Ghidra `12.1.4` and Apple LLVM `21.0.0` were used to trace the checks and verify
instruction boundaries. These commands inspect the relevant regions:

```bash
xcrun llvm-objdump -d --start-address=0x141b788a3 --stop-address=0x141b7890f "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141b7d810 --stop-address=0x141b7d850 "/path/to/bin/x64_dx12/witcher3.exe"
xcrun llvm-objdump -d --start-address=0x141ecf8c0 --stop-address=0x141ecfa50 "/path/to/bin/x64_dx12/witcher3.exe"
```

## Backups and file checks

The script uses macOS Bash 3.2 and bundled tools. It requires no downloads or
additional runtime. Supply the game path to apply, add `--restore` to restore,
or use `--help` for usage.

It checks that the game is closed, verifies the input hash and patch bytes,
and refuses unknown files, symlinks, hard links or conflicting backups. The
backup is `witcher3.exe.pre-dlss-wine-gate.2df765398a3d`; an existing backup must
match the original hash and is never overwritten.

Changes are prepared in a temporary file beside the executable. The output hash
is checked before replacement, and the input is checked again for changes.
File permissions, ownership, timestamps and extended attributes are preserved
where supported. Restore requires a verified backup and a recognized executable.
Repeated apply and restore are safe; both keep the backup.

## Interruption recovery

A crash or power loss can leave a `witcher3.exe.tmp.*` file, a
`witcher3.exe.dlss-wine-gate.lock` folder, or an incomplete backup beside the game
executable. Ordinary errors and Ctrl-C clean up the temporary file and lock.

1. Close the game and make sure the patcher is no longer running.
2. Keep copies of leftover files. Compare the executable and backup with the
   hashes above using `shasum -a 256 "/path/to/file"`.
3. Move an abandoned lock or incomplete backup out of the game folder only after
   confirming it belongs to the interrupted patch operation. Keep a valid backup.
4. Run apply or restore again. If the executable is unrecognized, use Steam's
   **Verify integrity of game files** to recover it.

Do not force the patch onto an unknown file. Atomic replacement does not
provide a guarantee against power loss on every filesystem.

## Validation

- Eleven temporary-file tests covered apply/restore, repeated operations,
  rejected inputs, backup conflicts and failure recovery. Six separate tests
  covered running-process detection. Test harnesses are not distributed.
- Apply and restore passed on copies of the supported executable, with the
  expected hashes. Disassembly confirmed all three replacements. File metadata,
  paths containing spaces/Unicode and running from another folder were checked.
- Process enumeration was mocked only in disposable fixture scripts during the
  final fixture run; production process checks remained intact.
- Bash syntax and Git whitespace checks passed.
- In-game testing confirmed selectable DLSS, frame generation and ray tracing.
  The HUD showed additional output frames and ray-tracing work. This does not
  establish stability or visual correctness throughout the entire game.
