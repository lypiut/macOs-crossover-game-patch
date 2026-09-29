# Agent instructions

## Goal
Improve Windows game support on macOS through CrossOver: fix compatibility and
unlock features such as HDR or investigate DLSS support. Verify game, backend,
and hardware capabilities; distinguish native features from replacements.
Deliver small, readable, reversible scripts usable on anyone's installation.

## Workflow
- Read `README.md`, `CONTRIBUTING.md`, and relevant patch docs; avoid duplicating
  them here. Keep detailed research beside the patch, not in this file.
- Inspect Git status and branch before editing; preserve unrelated work.
- Use one focused `codex/<topic>` branch per task; reuse the current task branch.
  Start new work from the appropriate verified base, never directly on main.
- For parallel tasks, use separate worktrees and branches, one per active task.
  Prefer managed worktree tools when available. Reuse a suitable idle worktree;
  never switch branches in another task's checkout or overwrite its changes.
- Define file ownership for parallel work, coordinate shared-file edits, and
  review and test combined changes before integration. Do not merge, reset,
  delete, or archive another task's work without accounting for its state.
- Keep changes scoped: games in `games/<game>/`, runtime tools in `tools/<tool>/`.
  Review diffs; stage only intended files. Report changes, checks, and limitations.

## Research
- Reproduce the symptom; separate observations, hypotheses, and verified results.
  Prefer configuration fixes and game-local changes over binary or shared fixes.
- Record game/store/build and executable SHA-256, CrossOver/macOS versions,
  graphics backend, and DirectX mode. Mark missing information as unknown.
- Explain why each change fixes the symptom. Document reproducible commands,
  tool versions, file offsets versus virtual addresses, and original/replacement
  bytes. Validate hook instruction boundaries, calling conventions, and control
  flow. Never reuse offsets on another build without verification.
- Stay within compatibility work; do not bypass ownership, DRM, anti-cheat, or
  system security protections.

## Trust
- Patch legally obtained local files. Never distribute proprietary game files,
  CrossOver components, prepatched copies, or unverified resources.
- Prefer offline operation. Third-party payloads require official provenance,
  pinned revision/version, verified SHA-256, and redistribution permission.
  Verify before extraction/use; reject mismatches and mutable `latest` downloads.
  A checksum establishes identity, not trust.
- Preserve licenses, attribution, source references, local modifications, and
  reproducible build instructions for distributed generated assets.
- No download-to-shell execution, opaque installers, silent dependency installs,
  telemetry, hidden uploads, credentials, or personal paths. Document dependencies
  and network access; link official installation instructions.

## Script contract
- Accept explicit paths; optional discovery must resolve ambiguity with the user.
  No fixed usernames, bottles, volumes, or library paths. Resolve bundled files
  relative to the script; support spaces, Unicode, and any working directory.
- Quote paths; never use `eval` for input. Prefer macOS tools and bundled Bash;
  document additional runtime requirements rather than assuming availability.
- Provide help, read-only check/dry-run, apply, and restore. Show target, scope
  (game/bottle/application), changes, and backups. Require explicit apply intent;
  support documented unattended flags and actionable errors/nonzero failures.
- Preflight prerequisites, stopped processes where required, permissions, target
  state, payloads, and conflicts before modifying installed files.
- Binary patches: allowlist original SHA-256, check every patch site's bytes,
  and verify output SHA-256 before installation. Refuse unknown or inconsistent
  states without a force bypass. Config edits: validate structure and values,
  preserving unrelated settings. Repeated apply/restore must be safe.
- Create and verify backups; never overwrite originals in existing backups.
  Reject destination conflicts, unexpected symlinks, and changed inputs.
- Stage and validate on the destination filesystem; replace atomically where
  possible and preserve required metadata. Provide rollback and interruption
  recovery for multi-file changes. Clean up only owned temporary files.
- Restore only patch-owned changes after verifying backup/payload identity.
  Preserve later unrelated user edits; refuse conflicts. Keep verified backups.

## Validation and delivery
- Use disposable fixtures or recoverable copies. Test changed logic for apply,
  repeat apply, output verification, restore/repeat restore, unsupported inputs,
  backup/payload conflicts, and relevant failures/interruptions. Read-only modes
  and rejected inputs must leave targets unchanged. Never weaken production
  validation for tests or commit proprietary fixtures.
- Check portable paths and invocation from another directory. Run `bash -n` for
  changed shell scripts, relevant language checks, and `git diff --check`.
  Documentation-only edits need no runtime tests.
- Report static, fixture, supported-build, and in-game checks separately. Never
  claim unrun tests. Label unvalidated behavior experimental; list remaining
  checks. A launch or screenshot alone does not prove feature correctness.
- Patch docs must cover requirements, supported builds/hashes, exact operations,
  apply/check/restore commands, update effects, limitations, evidence, and notices.
