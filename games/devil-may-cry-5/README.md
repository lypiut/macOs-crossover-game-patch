# Devil May Cry 5 HDR

Play the tested **DX11** version of DMC5 in HDR on CrossOver with **D3DMetal**.
The patcher checks the game, preserves the original executable, and can undo
its own work. DX12 is not supported.

## Before you begin

Quit Steam and the game. In `dmc5config.ini`, set `TargetPlatform=DirectX11`
and `UseVendorExtention=Enable`; then make sure the Mac display is ready for
HDR/EDR.

## Turn on HDR

Run the guided patcher and choose the game executable when asked:

```bash
./patch-hdr.sh
```

The original is kept as `DevilMayCry5.exe.pre-hdr`. Run the tool again whenever
you want to restore it. For automation:

```bash
./patch-hdr.sh --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

## Video crash?

If a video causes a crash—for example in customisation—use the
[CrossOver system-GStreamer patcher](../../tools/crossover-system-gstreamer/README.md).
