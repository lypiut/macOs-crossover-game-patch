# The Witcher 3 — CrossOver graphics patch

Removes the game's Wine checks that block DLSS, frame generation and ray tracing.
With GPTK, DLSS upscaling and frame generation use Apple's MetalFX.

## Requirements

- **Steam build 25773555**, using the DirectX 12 version.
- CrossOver with **D3DMetal** selected and **DLSS** enabled for the game's bottle.
  Tested with CrossOver Preview `27.0.0.41069`, GPTK `4.0b3` and macOS `27.0`.

The script uses tools included with macOS. It checks the executable before
patching and saves the original as a backup.

## Apply

Quit Witcher 3 first.

1. Download and extract the project using **Code → Download ZIP** on GitHub.
   Find `patch-dlss.sh` in `games/witcher-3`.
2. Open **Terminal**: press **⌘ Space**, type `Terminal`, then press **Return**.
3. Type `bash` and a space, drag `patch-dlss.sh` into Terminal, add a space,
   then drag in your **The Witcher 3** game folder. Use the folder containing
   `bin` and `content`, usually under `steamapps/common` in your Steam library.
4. Press **Return**. Wait for `apply completed and verified`.

Example command—replace both paths with your own:

```bash
bash "/path/to/patch-dlss.sh" "/path/to/The Witcher 3"
```

Keep `witcher3.exe.pre-dlss-wine-gate.2df765398a3d` beside the executable;
restore uses this backup.

## Restore

Quit the game. Run the same command with `--restore` before the game folder:

```bash
bash "/path/to/patch-dlss.sh" --restore "/path/to/The Witcher 3"
```

You can drag the paths into Terminal as above. Wait for
`restore completed and verified`.

## Troubleshooting

- **Unsupported executable:** the build differs or another mod changed it.
  The script stops without patching.
- **Game still running:** close Witcher 3 and try again.
- **Rendering problems:** restore the original executable.
- **Steam updates or Verify integrity:** these can remove the patch. A changed
  build needs a compatible patch.
- **Interrupted operation or backup conflict:** follow the
  [recovery instructions](TECHNICAL.md#interruption-recovery).

[Technical reference](TECHNICAL.md): exact changes, supported hashes and tests.

Independent community patch. No game files or CrossOver components are included.
Original patcher code uses the repository's MIT license.
