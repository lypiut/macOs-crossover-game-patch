# The Witcher 3 — DLSS patch for CrossOver

Witcher 3 checks whether it is running under Wine. In this build, that check
stops the game from loading Streamline, the library it uses for DLSS. The graphics
menu then reports DLSS as unsupported.

This patch changes two bytes in the game's DX12 executable so Streamline can
initialize and check for DLSS support.

**Experimental: the script has been tested on copies of the executable, but DLSS
has not yet been tested in game.** Frame generation has a separate Wine check
and is outside this patch.

## Before you start

You need:

- Steam build **25773555**. The script checks the exact executable and refuses
  other builds or modified files.
- CrossOver with **D3DMetal** selected and **DLSS** enabled. The investigation
  used CrossOver Preview `27.0.0.41069` with GPTK `4.0b3`.
- Python **3.9 or newer**. If needed, install it from
  [python.org](https://www.python.org/downloads/macos/).

Quit Witcher 3 before applying or restoring the patch. Keep the backup until
you have finished testing.

## Apply

Open Terminal in this folder. Replace the example path with your game folder:

```bash
./patch-dlss.sh --check "/path/to/The Witcher 3"
./patch-dlss.sh --apply "/path/to/The Witcher 3"
```

The first command checks your installation without changing it. The second
shows the planned change and asks for confirmation.

You can also pass the path to `bin/x64_dx12/witcher3.exe`. Keep paths in quotes
if they contain spaces. To run from another folder, use the full path to
`patch-dlss.sh`.

The script saves the original beside the executable as
`witcher3.exe.pre-dlss-wine-gate.2df765398a3d`. It checks the backup and patched
file before installing the change. Applying again is safe.

For a preview, use `--dry-run`. For unattended apply, use `--apply --yes`.
Run `--help` to see all options.

## Try DLSS

Launch the **DirectX 12** version and try selecting DLSS in the graphics menu.
Keep frame generation off for this first test.

Check image quality, performance and stability during gameplay. The menu becoming
selectable is only the first check; it does not prove that upscaling works.
CrossOver implements DLSS through MetalFX.

If the game crashes or renders incorrectly, restore the original executable.

## Undo

With the game closed:

```bash
./patch-dlss.sh --restore "/path/to/The Witcher 3"
```

Restore keeps the backup. It refuses to overwrite an executable changed by an
update or another mod. Use `--restore --yes` for unattended restore.

Steam updates or **Verify integrity** can remove the patch. Run `--check` after
an update. A different build needs fresh analysis before it can be supported.

If the script reports a backup conflict or an interrupted operation, stop and
follow [the recovery instructions](TECHNICAL.md#interruption-recovery).

## Test status and details

The script passed fixture tests and apply/restore tests on a copy of the
supported executable. Your installed game was left unchanged during development.
Patched in-game behavior remains untested.

[Technical notes](TECHNICAL.md) cover the supported hashes, exact change,
reverse-engineering evidence and test commands.

This is an independent community patch. Only patcher code and notes are
provided; no game files or CrossOver components are distributed. The original
patcher code uses the repository's MIT license.
