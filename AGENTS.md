# Telegraphica Agent Rules

These project rules apply to Codex work in this repository.

## Git Flow

- Use git-flow style branches.
- `main` is the protected release/base branch.
- Create `develop` from `main`.
- Create task branches from `develop`; do implementation and verification there.
- After local checks pass and the code does not crash in the available smoke tests, merge the task branch into `develop`.
- The user performs HITL/live validation from `develop`.
- Merge `develop` into `main` only after HITL approval, and use a teamlead/reviewer subagent for that final merge review when subagents are available.
- Codex owns git operations for the project: branching, commits, merges, comments, and pushes.

## Collaboration

- Do not be stingy with analysis tokens; prefer careful engineering over shallow changes.
- Use subagents aggressively when the user explicitly asks for deep or delegated project work and tools are available:
  - worker agents may implement bounded tasks;
  - verifier agents should review worker output;
  - additional reviewer agents may cross-check verification when the risk is meaningful.
- Keep branch write scopes clear when multiple agents are active.
- Ask the user questions during development when product, credential, legacy-machine, or HITL decisions are genuinely unclear.

## Project Constraints

- Target OS: OS X 10.9.5 Mavericks.
- Target architecture: Intel x86_64.
- Target toolchain: Xcode 6.2-compatible where possible.
- Use Objective-C, Cocoa, and AppKit.
- Do not use Swift, SwiftUI, official Telegram branding/logo/assets, or macOS 10.10+ APIs without a Mavericks-safe fallback.
- Do not commit Telegram `api_id`, `api_hash`, sessions, phone numbers, login codes, TDLib databases, generated database keys, or local credentials.

## Workspace Hygiene

- Clean up temporary files, extracted source trees, and test copies created during investigation or builds, especially under `/tmp`, `/private/tmp`, and system temp folders.
- Keep only necessary and current transfer/build artifacts readily available; remove obsolete archives, superseded builds, and stale diagnostic files after a newer verified artifact replaces them.
- Keep `dist/` focused on the latest project transfer archive plus currently needed dependency/source packages, unless an older artifact is intentionally preserved for rollback.
- Before finishing work that created large local artifacts, check the relevant temp/output directories and delete known unneeded files without touching user-created or unrelated files.
