# Devil May Cry 5 HDR

Enable DMC5 HDR on CrossOver Preview/D3DMetal with one game-binary patch that
works with both DirectX 11 and DirectX 12. The patcher checks the exact game
build, makes a backup first, verifies every patch, and restores the original on
request. It does not modify D3DMetal, CrossOver, Steam settings, or the game INI.

## What the patch fixes

DMC5 has two different HDR paths:

- **DX11:** the game rejects the renderer HDR path before D3DMetal can present
  HDR. The patch opens that existing renderer gate.
- **DX12:** the game selects a null HDR service when the CrossOver adapter does
  not look like a supported GPU vendor. The patch lets DMC5 run its own HDR
  transition, then labels the DX12 swapchain as HDR10/PQ so D3DMetal/macOS can
  enable the XDR HDR output path.

The patch combines these backend-specific changes in one executable. The DX12
swapchain hook is reached only by the DX12 creation path; validate the combined
binary once in each backend before treating it as fully runtime-verified.

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

Choose **Apply the universal DX11/DX12 HDR patch**, then paste or drag
`DevilMayCry5.exe` into Terminal. The tool replaces the executable in place,
because Steam launches that exact filename, and keeps the untouched original as
`DevilMayCry5.exe.pre-hdr`.

Run the tool again and choose **Restore** to return to the original executable.
The backup remains in place and is verified before restoration.

For unattended use:

```bash
./patch-hdr.sh --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

To check an executable without changing it:

```bash
./patch-hdr.sh --check "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

## Calibration

Use DMC5's own HDR brightness and maximum-brightness controls to tune paper
white and peak brightness. Do not try to tune the image by editing D3DMetal.

The DX12 component was accepted on Apple Display XDR: the game retained dark
detail and midtones while bright emitters and reflections were localized rather
than globally over-bright. The combined executable should be tested once with
each backend before treating this exact release as fully runtime-verified.

## Video crash?

If a video causes a crash—for example in customisation—use the
[CrossOver system-GStreamer patcher](../../tools/crossover-system-gstreamer/README.md).
