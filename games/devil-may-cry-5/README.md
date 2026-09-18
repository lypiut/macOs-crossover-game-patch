# Devil May Cry 5 HDR patch

This patch enables DMC5 HDR when the game runs through CrossOver Preview and
D3DMetal. It supports both DirectX 11 and DirectX 12.

The patch installs:

- a modified `DevilMayCry5.exe` that enables DMC5's HDR paths;
- `re_chunk_000.pak.patch_008.pak`, which contains two HDR shader replacements.

The original executable is saved as `DevilMayCry5.exe.pre-hdr`.

## Requirements

- CrossOver Preview with D3DMetal;
- an HDR-capable display;
- the supported DMC5 executable build.

Quit DMC5 before applying or restoring the patch. The patcher checks the game
build before it changes anything. It supports this executable SHA-256:

`1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d`

## Install

From this directory, run:

```bash
./patch-hdr.sh
```

Choose **Apply the HDR patch**, then drag the game's `DevilMayCry5.exe` into
Terminal. The patcher creates the backup and installs the shader archive next to
the executable.

For command-line use:

```bash
./patch-hdr.sh --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

Check the installation without changing anything:

```bash
./patch-hdr.sh --check "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

## Restore

Use the guided patcher and choose **Restore**, or run:

```bash
./patch-hdr.sh --restore --yes "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

This restores the original executable and removes the shader archive installed
by this patch. The backup is kept.

## HDR settings

Select DirectX 11 or DirectX 12 in DMC5's graphics settings. Use DMC5's HDR
brightness and maximum-brightness controls to match the game to your display.

The patch has no runtime dependency on RenoDX, ReShade, or REFramework. The two
shader replacements are loaded by DMC5 from a normal RE Engine patch archive.

## Technical notes

DMC5 normally rejects its native HDR path when the CrossOver adapter does not
match the vendor names expected by the game. The executable patch enables the
existing HDR transition for both backends and makes the DX12 swapchain request
HDR10/PQ.

The shader archive replaces DMC5's HDR post-process and final Rec.2020/PQ
conversion shaders. These replacements are adapted from the DMC5 module in
RenoDX and use DMC5's existing brightness controls.

## Screenshots

<!-- Add before/after HDR screenshots here. A DX12 scene with the Metal HUD is
     useful for showing the active backend and HDR output. -->

## Credits

Shader work is adapted from [RenoDX](https://github.com/clshortfuse/renodx)
under the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
