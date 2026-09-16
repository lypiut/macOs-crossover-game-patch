# Devil May Cry 5 HDR under CrossOver

This small tool enables HDR in the tested **DirectX 11** version of Devil May
Cry 5 when using CrossOver's D3DMetal graphics backend.

It is deliberately cautious: it checks that your game executable is the one
this patch supports, makes a backup before changing anything, and verifies the
result. If Steam updates the game, the tool will stop safely instead of trying
to patch an unknown file.

> [!IMPORTANT]
> This is a DX11 HDR patch. DX12 is not supported by this version of the tool.

## Before you start

- Close Devil May Cry 5 and Steam.
- Use CrossOver with **D3DMetal**.
- In `dmc5config.ini`, select `TargetPlatform=DirectX11` and set
  `UseVendorExtention=Enable`.
- Make sure your Mac display is already configured for HDR/EDR.

## Recommended: guided patcher

In Terminal, go to this folder and run:

```bash
./patch-hdr.sh
```

Choose **Apply the DX11 HDR patch**, then paste or drag `DevilMayCry5.exe` into
the Terminal window. The tool explains every change before it happens.

It patches the game executable in place because Steam normally launches the
file with that exact name. Your untouched original is kept next to it as
`DevilMayCry5.exe.pre-hdr`.

To undo the patch, run `./patch-hdr.sh` again and choose **Restore the original
game executable**. The backup is retained, so it is never silently replaced.

## Optional: automation

For a script or an experienced Terminal user, this applies the same verified
patch without prompts:

```bash
./patch-hdr.sh --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

It still creates and verifies the backup before replacing the executable.

## Current limitation

HDR activation has been confirmed with DX11/D3DMetal. The game's crash in the
customisation/equipment menu is a separate issue and is not fixed by this HDR
patch.
