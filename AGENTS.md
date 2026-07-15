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

## Mountain Lion Git Flow

- OS X 10.8.5 Mountain Lion work must stay entirely inside the `mountain-lion/*` branch namespace.
- Use `mountain-lion/main` as the Mountain Lion release/base branch.
- Use `mountain-lion/develop` as the Mountain Lion integration branch.
- Create Mountain Lion task branches from `mountain-lion/develop`, using names such as `mountain-lion/feature/<slug>` or `mountain-lion/fix/<slug>`.
- Merge Mountain Lion task branches back only into `mountain-lion/develop` after local and old-Mac checks pass.
- Merge `mountain-lion/develop` into `mountain-lion/main` only after Mountain Lion HITL approval.
- Do not merge, commit, or push OS X 10.8-specific build, TDLib, compatibility, or release work into the ordinary `main` or `develop` branches unless the user explicitly asks to port a shared, non-10.8-specific change.

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
- When adding UI or feature code, prefer focused component/helper files over growing large controllers such as `TGStatusWindowController.m`; keep new modules cohesive and import them from the owning controller.
- Do not let one file become a broad mixed-responsibility dump. If a feature adds a meaningful amount of UI, media, data-flow, presentation, or TDLib orchestration code, split that area into a small focused file during the same task.
- For refactors of oversized files, prefer substantial cohesive moves of complete method groups or helper responsibilities over tiny cosmetic reductions. Verify with local checks and, when relevant, the remote Mavericks HITL build flow.
- Do not commit Telegram `api_id`, `api_hash`, sessions, phone numbers, login codes, TDLib databases, generated database keys, or local credentials.
