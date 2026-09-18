# Devil May Cry 5 HDR

Enable DMC5 HDR on CrossOver Preview/D3DMetal with one patched executable that
works with both DirectX 11 and DirectX 12, plus one offline shader PAK. The
patcher checks the exact game build, makes a backup first, verifies every file,
and restores the original on request. It does not modify D3DMetal, CrossOver,
Steam settings, or the game INI, and it does not install a runtime mod loader.

## What the patch fixes

DMC5 has two different HDR paths:

- **DX11:** the game rejects the renderer HDR path before D3DMetal can present
  HDR. The patch opens that existing renderer gate.
- **DX12:** the game selects a null HDR service when the CrossOver adapter does
  not look like a supported GPU vendor. The patch lets DMC5 run its own HDR
  transition, then labels the DX12 swapchain as HDR10/PQ so D3DMetal/macOS can
  enable the XDR HDR output path.

The executable combines these backend-specific changes. The shader PAK adds two
offline replacements derived from the open-source RenoDX DMC5 shaders:

- `HDRPostProcess` preserves HDR highlight energy through DMC5's post-process
  and colour-grading stage.
- `ConvertRec2020` converts the final image to BT.2020/PQ using DMC5's existing
  paper-white and peak-brightness values.

No RenoDX add-on, ReShade, or REFramework runtime is installed. DMC5 loads the
two replacement shaders from a normal RE Engine patch PAK.

## Before you start

- Quit DMC5 and Steam.
- Use CrossOver with D3DMetal and make sure macOS HDR/EDR is available on the
  connected display.
- Choose your preferred API in DMC5: `DirectX11` or `DirectX12`.
- This patch supports only the executable with SHA-256
  `1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d`.
  If Steam updates the game, the patcher stops without writing anything.

## Apply or restore

Run the guided patcher from this directory:

```bash
./patch-hdr.sh
```

Choose **Apply the complete DX11/DX12 HDR patch**, then paste or drag
`DevilMayCry5.exe` into Terminal. The tool replaces the executable in place,
because Steam launches that exact filename, keeps the untouched original as
`DevilMayCry5.exe.pre-hdr`, and installs one verified
`re_chunk_000.pak.patch_008.pak` beside it.

Run the tool again and choose **Restore** to return to the original executable
and remove only the exact shader PAK installed by this patch. The backup remains
in place and is verified before restoration. A different file using the same
PAK name is treated as a conflict and is never overwritten or removed.

For unattended use:

```bash
./patch-hdr.sh --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

To check an executable without changing it:

```bash
./patch-hdr.sh --check "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

The check reports the executable and shader-PAK states separately. This makes a
partial or conflicting installation visible before the game is launched.

## Calibration

Use DMC5's own HDR brightness and maximum-brightness controls to tune paper
white and peak brightness. Do not try to tune the image by editing D3DMetal.

The complete DX12 path was accepted on Apple Display XDR: the game retained dark
detail and midtones while bright emitters and reflections were localized rather
than globally over-bright. The two shader replacements use shared RE Engine
resources, so they are also available to DX11; the final two-shader package has
so far been runtime-accepted in DX12.

## Credits

The HDR shader work is adapted from the DMC5 module in
[RenoDX](https://github.com/clshortfuse/renodx), used under the MIT License. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Video crash?

If a video causes a crash—for example in customisation—use the
[CrossOver system-GStreamer patcher](../../tools/crossover-system-gstreamer/README.md).
