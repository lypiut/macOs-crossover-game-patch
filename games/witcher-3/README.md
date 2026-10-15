# The Witcher 3 — CrossOver graphics patch

This patch removes game checks that block DLSS, frame generation and ray tracing
under Wine. The game still checks whether each feature is supported. With the
tested GPTK runtime, the DLSS options use MetalFX upscaling and frame
interpolation rather than NVIDIA's DLSS models.

User testing on 15 October 2026 confirmed that all three options can be enabled.
The HUD shows additional output frames with frame generation and ray-tracing
commands with ray tracing.

## Requirements

- Steam build **25773555**, using the DirectX 12 executable. The script verifies
  the exact file and refuses other builds or modified executables.
- CrossOver with **D3DMetal** selected and **DLSS** enabled. The investigation
  used CrossOver Preview `27.0.0.41069` with GPTK `4.0b3`.
- macOS and its bundled Bash and command-line tools. No Python or downloads are
  needed.

## Apply

Quit Witcher 3. Open Terminal in this folder and supply your game folder:

```bash
./patch-dlss.sh "/path/to/The Witcher 3"
```

This applies all three changes and saves the original executable beside it as
`witcher3.exe.pre-dlss-wine-gate.2df765398a3d`. Keep that backup.

Applying again is safe. The script accepts only the original executable or
the full patch.

You can also supply `bin/x64_dx12/witcher3.exe` directly. Use the full script path
when running from another folder. Keep paths with spaces in quotes.

## Test

Launch the **DirectX 12** version. Start with DLSS, then try frame generation and
ray tracing separately through the graphics settings. Check stability and image
quality during gameplay. A selectable option alone does not prove it works.

If the game crashes or renders incorrectly, restore the original executable.

## Known limitations

- Frame generation increased the HUD output rate from about 52 to 72 FPS in the
  reported scene, while the rendered frame rate fell to about 31 FPS. It did not
  reach the display's maximum refresh rate. The cause of the slowdown and pacing
  behavior is still under investigation.
- The number of generated frames could not be changed in the graphics menu.
- These results cover the tested setup and scene; they do not establish image
  quality or stability across the whole game.

## Restore

With Witcher 3 closed:

```bash
./patch-dlss.sh --restore "/path/to/The Witcher 3"
```

Restore keeps the backup. It refuses to overwrite an executable changed by an
update or another mod.

Steam updates or **Verify integrity** can remove the patch. A new build needs
fresh analysis before it can be supported. If the script reports an interrupted
operation, follow [the recovery instructions](TECHNICAL.md#interruption-recovery).

## Details

The Bash script passed temporary-file tests and apply/restore tests on copies of
the supported executable. These tests did not change the installed game or launch
it. The user then tested all three features in game on an M4 Pro running macOS
27.0, using the CrossOver/GPTK versions listed above.

[Technical notes](TECHNICAL.md) record the exact changes, supported hashes and
validation results. [Investigation notes](FEATURE_GATES.md) explain the other
Wine checks that are deliberately preserved.

This is an independent community patch. No game files or CrossOver components
are distributed. The original patcher code uses the repository's MIT license.
