# Contributing

Thanks for helping improve CrossOver game compatibility on macOS. Bug reports,
test results, documentation fixes, and carefully scoped patches are welcome.

## Before opening an issue

Check the documentation for the relevant patch and confirm that:

- the game, CrossOver, and macOS are fully restarted where required;
- your game build is supported by the patch;
- the problem still occurs with the original files restored;
- Steam's **Verify integrity of game files** has not silently removed the patch;
- an existing issue does not already cover the same problem.

When reporting a bug or compatibility result, include:

- Mac model and chip;
- macOS version;
- CrossOver version and edition;
- graphics backend, such as D3DMetal, DXMT, or DXVK;
- game version and executable SHA-256, when available;
- DirectX mode, if relevant;
- the exact command used and complete error output;
- whether restoring the original files fixes the problem.

Do not upload game executables, game assets, CrossOver components, license
keys, credentials, or other material you do not have permission to distribute.

## Proposing a patch

Open an issue before investing substantial effort in a new game patch. Explain
the problem, the affected versions, the proposed change, and how you verified
it. This gives maintainers and other testers a chance to identify licensing,
safety, or compatibility concerns early.

A patch should:

- solve one clearly defined compatibility problem;
- verify exact supported inputs before making changes;
- refuse unknown or already modified files safely;
- show the user what will change before requesting confirmation;
- create and verify a backup where files are modified;
- provide a tested restore path;
- avoid downloading or installing unrelated software;
- document its requirements, behavior, limitations, and file operations;
- be safe to run more than once;
- produce useful error messages without exposing private information.

Prefer readable shell scripts and standard macOS tools. If an external
dependency is necessary, explain why and link to its official installation
instructions.

## Pull requests

Keep pull requests focused. Include:

1. A concise explanation of the problem and solution.
2. The exact game and CrossOver versions tested.
3. Test steps for applying, checking, and restoring the patch.
4. Relevant hashes or other evidence used to identify supported builds.
5. Screenshots when they demonstrate a visual change.
6. Any known limitations or remaining risks.

Before submitting, run these basic checks from the repository root:

```bash
bash -n path/to/changed-script.sh
git diff --check
```

Also exercise every changed operation against disposable test files or a game
installation that can be restored. Never test destructive behavior for the
first time on a user's only copy.

## Documentation style

Write for people who may be new to CrossOver or Terminal:

- use direct, plain language;
- provide commands that can be copied as written;
- distinguish required steps from optional ones;
- state whether a change affects one game, one bottle, or the whole CrossOver
  application;
- always explain how to undo a change.

## Licensing and attribution

Only submit work that the project is allowed to distribute. Do not include
copyrighted game files or proprietary CrossOver components.

For code, shaders, binaries, or other material derived from an open-source
project:

- identify the upstream project and exact source revision;
- preserve copyright and license notices;
- document local modifications;
- include the applicable license or notice;
- provide corresponding source or build instructions when the upstream license
  requires them.

The repository's MIT License does not relicense third-party material. If the
origin or redistribution terms of an artifact are unclear, do not submit it
until they have been resolved.

## Responsible disclosure

Do not publish credentials, personal information, or details of an unpatched
security vulnerability in a public issue. Contact the maintainer privately
when a report may have security implications.
