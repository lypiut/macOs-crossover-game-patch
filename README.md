# macOS CrossOver game patches

Small, reviewable compatibility patches for Windows games running through
CrossOver on macOS.

Each game has its own directory with:

- a patcher that refuses unknown game builds;
- documentation for the exact behavior being changed;
- known backend-specific limitations and a rollback path.

## Patches

- [Devil May Cry 5 HDR](games/devil-may-cry-5/README.md)

The repository does not distribute game binaries or proprietary CrossOver
components.

## Safety

Close the game before patching. Keep Steam's **Verify integrity of game files**
feature in mind: it can restore modified executables. Prefer the patchers'
side-by-side output mode unless a game launcher requires the original filename.

## License

[MIT](LICENSE)
