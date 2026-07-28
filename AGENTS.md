# Telegraphica Agent Rules

These project rules apply to Codex work in this repository.

## Git Flow

- Use git-flow style branches.
- `main` is the protected release/base branch.
- Create `develop` from `main`.
- Create task branches from `develop`; do implementation and verification there.
- Name task branches by work type, for example `feature/...`, `fix/...`, `hotfix/...`, or `test/...`.
- Do not use AI assistant, model, or tool names in branch names, including `codex`, `gemini`, `claude`, `groq`, or similar prefixes.
- After local checks pass and the code does not crash in the available smoke tests, merge the task branch into `develop`.
- The user performs HITL/live validation from `develop`.
- Merge `develop` into `main` only after HITL approval, and use a teamlead/reviewer subagent for that final merge review when subagents are available.
- Codex owns git operations for the project: branching, commits, merges, comments, and pushes.

## Collaboration

- Treat Telegraphica as an established, viable product under active development. Do not repeat early-stage feasibility or "is it worth continuing?" audits during normal feature, bug-fix, build, or TDLib work.
- Revisit overall feasibility only when new, concrete evidence reveals a persistent blocker that threatens the complete product lane, such as an unresolvable Telegram authorization break or an inability to run any compatible TDLib on the supported systems. First exhaust focused diagnostics and distinguish a local regression from a product-level blocker.
- Keep analysis and verification proportional to the change. Prefer careful engineering, but do not reopen settled product decisions, reread unrelated history, rerun unchanged expensive checks, or produce long status/handoff text unless it helps the current task.
- Use subagents when the user explicitly asks for deep or delegated project work and there is a concrete independent subtask:
  - worker agents may implement bounded tasks;
  - verifier agents should review worker output;
  - additional reviewer agents may cross-check verification when the risk is meaningful.
- Keep branch write scopes clear when multiple agents are active.
- Ask the user questions during development when product, credential, legacy-machine, or HITL decisions are genuinely unclear.

## Unified Legacy Release

- Treat OS X 10.8 through macOS 10.13 as one product and release lane. The canonical deliverable is one Intel `x86_64` application built from one source tree, one application target, and one build/package pipeline.
- Do not split compatibility work into separate Mountain Lion and Mavericks source trees, long-lived OS-specific branches, duplicated project files, generated source variants, app bundles, DMGs, or ZIPs. Historical `mountain-lion/*` branches are reference-only; start all new work from `develop`.
- Keep the shared deployment target at OS X 10.8. Implement unavoidable OS differences inside the common codebase with runtime capability/version checks and focused compatibility helpers. Use conditional compilation only when an SDK or compiler difference cannot be handled at runtime.
- Preserve the normal 10.9-10.13 feature path while providing 10.8-safe fallbacks. If a feature or optional Workshop module requires 10.9 or newer, express that through availability metadata and runtime gating instead of forking the host application or release.
- Treat platform checks as complementary validation of the same deliverable. Release candidates and changes that touch runtime gating, packaging, dependencies, or shared compatibility code should cover both the OS X 10.8 fallback and the 10.9-10.13 normal path. Ordinary feature iterations may use the relevant available legacy Mac unless the change affects the other path.
- Use one stable old-Mac source/build folder, `~/Desktop/Telegraphica-current`, for the unified lane on every supported OS. Validation logs may be separated and labelled by OS, but they must refer to the same source revision and release candidate.
- Produce one canonical release artifact set named for the complete range, such as `macos10.8-10.13-x86_64`. Do not publish separate `ml`, `mountain-lion`, `mavericks`, or `macos10.9` variants unless the user explicitly authorizes a temporary diagnostic build.
- If a dependency or toolchain appears to require divergent product artifacts, stop and raise the incompatibility for a product decision instead of silently creating a second lane.

## Remote HITL Builds

- Prefer the configured `telegraphica-mavericks` SSH alias for old-Mac HITL builds when it is available; do not use raw IP addresses unless the user explicitly asks.
- After copying, building, and launching a HITL build on the old Mac, clean up obsolete Telegraphica-only transfer archives and scratch build clutter created by that run. Use narrow exact-path cleanup and do not touch user files, `~/Library/Application Support/Telegraphica`, TDLib databases, Telegram sessions, credentials, or unrelated Desktop items.
- When reporting a successful remote HITL build that has already been launched on the old Mac, do not include a terminal command block. Instead, state what changed and give a concise checklist of what the user should verify in the already-running app.
- When the user explicitly requests HITL and the app cannot be launched remotely, provide the normal complete old-Mac terminal command block for manual HITL. Do not add manual build instructions to unrelated development updates.

## Verification Efficiency

- Run the smallest check set that covers the changed surface. Use `./scripts/run_tests.sh` and `python3 scripts/check_legacy_compat.py` for broad source changes; use narrower checks for isolated documentation, assets, or scripts.
- Do not rebuild TDLib, repackage releases, create transfer archives, or run old-Mac HITL for answer-only work or rule/documentation edits.
- Do not repeat an unchanged expensive check in the same iteration unless new evidence invalidates its previous result.
- Modern-Mac builds are supporting diagnostics, not mandatory proof for every change. Use legacy compilation/HITL when the change is OS-, SDK-, packaging-, Keychain-, authorization-, media-, or runtime-sensitive.
- Release work begins only when the user explicitly requests a release. A normal feature request authorizes implementation and proportional verification, not release publication.

## Project Constraints

- Never invent, hand-draw, or generate replacement UI icons in code, including
  custom `NSBezierPath` glyphs. Use only user-provided or already approved
  project image assets. If no suitable asset exists, leave the icon placement
  empty and ask the user to provide or choose an icon before continuing.
- Do not implement purchases, checkout, Premium acquisition, Telegram Stars
  payments, paid subscriptions, paid messages/media, gifts, boosts, paid
  reactions, giveaways, or any other Telegram monetization transaction inside
  Telegraphica.
- Telegraphica may safely render already-existing paid or Premium-gated content
  when TDLib supplies it. If a user tries to manage a paid-only capability,
  explain that it is unavailable in Telegraphica and direct them to the
  official Telegram application. Never provide an in-app purchase path, payment
  link, billing flow, or wording that implies Telegraphica can sell it.
- Prefer and fully implement free Telegram functionality. Runtime capability
  gating must distinguish "unsupported by the loaded TDLib" from "available
  only through an official paid Telegram feature".
- Target OS: one application and release artifact for OS X 10.8 through macOS 10.13.
- Target architecture: Intel x86_64.
- Target toolchain: Xcode 5.1.1-compatible for the shared 10.8 deployment target, while preserving Xcode 6.2 compatibility.
- Use Objective-C, Cocoa, and AppKit.
- Do not use Swift, SwiftUI, official Telegram branding/logo/assets, or OS X 10.9+ APIs without a Mountain Lion-safe fallback.
- When adding UI or feature code, prefer focused component/helper files over growing large controllers such as `TGStatusWindowController.m`; keep new modules cohesive and import them from the owning controller.
- Do not let one file become a broad mixed-responsibility dump. If a feature adds a meaningful amount of UI, media, data-flow, presentation, or TDLib orchestration code, split that area into a small focused file during the same task.
- For refactors of oversized files, prefer substantial cohesive moves of complete method groups or helper responsibilities over tiny cosmetic reductions. Verify with local checks and, when relevant, the applicable unified legacy HITL checks.
- Do not commit Telegram `api_id`, `api_hash`, sessions, phone numbers, login codes, TDLib databases, generated database keys, or local credentials.
- Periodically clean `dist` from obsolete Telegraphica build archives and scratch artifacts after newer verified builds replace them, using narrow exact-path cleanup only.
