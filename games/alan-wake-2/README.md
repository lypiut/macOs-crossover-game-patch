# Alan Wake 2 — native HDR in CrossOver

This script enables Alan Wake 2's built-in HDR option by changing only
`m_eHdrQuality` from `0` to `1` in the game's `renderer.ini`. It does not patch
the game executable, install RenoDX, or change graphics or performance settings.

Quit Alan Wake 2 before using the script. Python 3 is required.

## Apply

Run from the repository root:

```bash
python3 games/alan-wake-2/enable-hdr.py
```

The script searches CrossOver bottles for Alan Wake 2's settings. If it finds
more than one installation, select the intended file explicitly:

```bash
python3 games/alan-wake-2/enable-hdr.py --config "/path/to/AlanWake2/renderer.ini"
```

The script validates the JSON and saves the original file as
`renderer.ini.pre-hdr` before making a change. Running it again is safe; it
reports when HDR is already enabled.

## Check or restore

```bash
python3 games/alan-wake-2/enable-hdr.py --check
python3 games/alan-wake-2/enable-hdr.py --restore
```

`--restore` changes only `m_eHdrQuality` back to the backed-up value, preserving
any other settings changed since the backup. Use the same `--config` argument
for check and restore commands when selecting a configuration explicitly.

The HDR option also depends on an HDR-capable display and a CrossOver graphics
backend that can present HDR. This script only changes the game's setting.
