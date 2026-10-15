# The Witcher 3 — CrossOver graphics patch

This patch removes game checks that block DLSS, frame generation and ray tracing
under Wine. The game still checks whether each feature is supported. With the
tested GPTK runtime, the DLSS options use MetalFX upscaling and frame
interpolation rather than NVIDIA's DLSS models.

In-game testing confirmed that all three options can be enabled.
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

- The number of generated frames could not be changed in the graphics menu.
- Testing covers the tested setup and scene; it does not establish image
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
it. All three features were also tested in game on macOS 27.0 with the
CrossOver/GPTK versions listed above.

[Technical notes](TECHNICAL.md) record the exact changes, supported hashes and
validation results, including the Wine compatibility checks left intact.

This is an independent community patch. No game files or CrossOver components
are distributed. The original patcher code uses the repository's MIT license.
