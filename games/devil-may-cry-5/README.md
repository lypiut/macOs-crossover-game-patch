# Devil May Cry 5 HDR under CrossOver

`patch-hdr.sh` enables DMC5's NVIDIA rendering path on the supported executable
build. This makes the game call the NVAPI HDR interface exposed by CrossOver's
D3DMetal implementation instead of rejecting Apple GPU adapter names.

The patch changes one conditional branch:

```text
file offset 0x02C2CE0F
before: 0F 84 C5 02 00 00
after:  90 90 90 90 90 90
```

Only the executable with SHA-256
`1b881b52184fbb4de08740d68e77b49093bf4c5e8310ba185454fd34eba18e1d`
is accepted. The expected patched SHA-256 is
`d9e3406b5d2f0a60eb999882eb36c17602ccfa0c84b763b3ac2112d9e668d643`.

## Usage

Close DMC5, then create a patched executable beside the original:

```bash
./patch-hdr.sh "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

The default output is `DevilMayCry5.hdr.exe`. A custom destination can be used:

```bash
./patch-hdr.sh --output /path/to/test/DevilMayCry5.exe \
  "/path/to/Devil May Cry 5/DevilMayCry5.exe"
```

Check an executable without changing it:

```bash
./patch-hdr.sh --check /path/to/DevilMayCry5.exe
```

In-place patching is available when the launcher requires the original name:

```bash
./patch-hdr.sh --in-place /path/to/DevilMayCry5.exe
```

This creates `DevilMayCry5.exe.pre-hdr` before replacing the executable.

## CrossOver configuration

- Use the DirectX 11 renderer in DMC5 (`TargetPlatform=DirectX11`).
- D3DMetal is the recommended backend for this patch.
- The macOS display must already be configured for HDR/EDR output.
- `MTL_HUD_ENABLED=1` may be set when launching to show Apple's Metal HUD; it
  is diagnostic and does not enable HDR by itself.

DXMT exposes NVAPI HDR calls when `DXMT_ENABLE_NVEXT=1`, but forcing DMC5's
complete NVIDIA path also makes it request
`NvAPI_D3D11_MultiDrawIndexedInstancedIndirect`. The tested DXMT build reports
that extension as unimplemented, so DXMT is not currently recommended for this
patch.

## Scope

This is a binary compatibility patch, not a general HDR mod. A game update will
normally change the executable hash; the script will then stop without writing
anything until the new build is analyzed.
