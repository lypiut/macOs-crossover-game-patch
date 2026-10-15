# The Witcher 3 — CrossOver graphics patch

Unlocks the DLSS, frame generation and ray tracing options that Witcher 3 blocks
when running through CrossOver. All three have been tested in game. With the
tested GPTK runtime, DLSS upscaling and frame generation use Apple's MetalFX.

## Before you start

- This patch supports **Steam build 25773555**, in **DirectX 12** mode. The script
  checks your game file and stops if it does not match.
- In CrossOver, select **D3DMetal** and enable **DLSS** for the bottle containing
  the game. Testing used CrossOver Preview `27.0.0.41069`, GPTK `4.0b3` and
  macOS `27.0`.
- Quit Witcher 3 before applying or removing the patch.

No Python or extra tools are needed. The patch only changes Witcher 3's DX12
executable and saves a backup first.

## Apply the patch

1. Download the repository ZIP from the GitHub branch containing this patch:
   choose **Code → Download ZIP**, then double-click the ZIP to extract it.
   If you already downloaded the project, use that copy.
2. In Finder, open `games`, then `witcher-3`. Find `patch-dlss.sh`.
3. Open a second Finder window and locate your **The Witcher 3** game folder.
   It is usually inside your Steam library's `steamapps/common` folder. Select
   the folder containing `bin` and `content`.
4. Press **⌘ Space**, type **Terminal**, then press **Return**.
5. Type `bash` followed by a space. Drag `patch-dlss.sh` from Finder into
   Terminal. This inserts its full path; you do not need to type it.
6. Add a space, then drag your **The Witcher 3** folder into Terminal.
7. Press **Return** and wait for `apply completed and verified`.

The command will look like this, with your own paths:

```bash
bash "/path/to/patch-dlss.sh" "/path/to/The Witcher 3"
```

Launch the game in **DirectX 12** mode and choose the features you want in the
graphics settings. The number of generated frames was not adjustable in testing.

Keep the backup named `witcher3.exe.pre-dlss-wine-gate.2df765398a3d` beside the
executable. Running the patch again is safe.

## Remove the patch

Quit the game and open Terminal. Type `bash` and a space, drag in the script,
then type ` --restore `, including the spaces. Drag in the game folder and
press **Return**:

```bash
bash "/path/to/patch-dlss.sh" --restore "/path/to/The Witcher 3"
```

Wait for `restore completed and verified`. The original executable is restored
and the backup is kept.

## If something goes wrong

- **Unsupported executable:** your game build differs or another mod changed
  the file. The script will not modify it.
- **Game still running:** close Witcher 3 and try again.
- **Rendering problems or crashes:** remove the patch using the command above.
- **After a Steam update or Verify integrity:** the patch may be removed. A new
  game build needs a matching patch; do not reuse offsets from another build.
- **Interrupted operation or backup conflict:** see
  [recovery instructions](TECHNICAL.md#interruption-recovery).

[Technical notes](TECHNICAL.md) contain the supported file hashes and exact
changes for anyone who wants to inspect them.

Independent community patch, unaffiliated with CD PROJEKT RED, CodeWeavers,
Apple or NVIDIA. No game files or CrossOver components are included. Original
patcher code is licensed under the repository's MIT license.
