# Telegraphica Feature Audit

Date: 2026-07-27
Verified code snapshot: `b77e491` (`feature/chat-folder-management`)

Scope: the unified OS X 10.8-macOS 10.13 application on the
`feature/chat-folder-management` branch.

This audit compares the current Telegraphica code with the Telegram client
surface and the current TDLib API. It distinguishes between:

- functionality already present in the UI and TDLib bridge;
- partial functionality with a usable foundation;
- missing functionality that can reasonably be added to the unified legacy app;
- modern Telegram areas that need a newer TDLib or a large separate project.

The current Telegram feature reference is the official
[Evolution of Telegram](https://telegram.org/evolution/) timeline. The API
reference is the official [TDLib documentation](https://core.telegram.org/tdlib/docs/)
and [TDLib class index](https://core.telegram.org/tdlib/docs/classes.html).

The audit was refreshed after the folder and contact-avatar HITL fixes. It is
based on the public `TGTDLibClient` surface, all TDLib request types used by the
implementation, the AppKit controllers and focused UI modules, the current
static/unit probes, and the feature's successful Mavericks HITL pass. A visible
button without its matching TDLib read/write path is counted as partial, not
complete.

## Executive Summary

Telegraphica is no longer a minimal text-only spike. It already covers a large
daily-use subset:

- phone, code and 2FA login with encrypted local TDLib storage;
- chat list, archive, folders, search, forum topics and comment threads;
- message reading with viewport-based read state;
- text, replies, forwarding, editing, deletion and pinning;
- photos, albums, GIF animations, video, audio, documents, stickers and voice;
- contacts, locations and regular polls;
- emoji reactions, drafts, pinned messages and supported reader lists;
- downloads, Save As, Finder reveal, media center, preview and playback;
- contact management, basic chat creation and profile editing;
- active sessions, cache management, local notifications and appearance settings.

The highest-value missing layer is no longer basic messaging. It is account and
chat management around messaging: server-synchronized notification settings,
participants and administration, send options, privacy controls, a real
download manager and richer bot support.

## Product Boundary: Free Features Only

Telegraphica will not implement Telegram Premium purchasing, Stars payments,
paid subscriptions, paid messages or media, gifts, boosts, paid reactions,
giveaways, or any other monetization transaction.

Already-existing paid content may be rendered read-only when TDLib supplies a
safe representation. An attempted paid-only action must show a neutral
explanation that it is unavailable in Telegraphica and can be managed in the
official Telegram application. No checkout, payment link, purchase prompt or
billing workflow belongs in the app.

## Current Coverage

| Area | Current status | Important remaining work |
| --- | --- | --- |
| Authorization | Phone number, code, 2FA password, session reuse, Keychain database key, logout | QR login, registration, email codes, recovery, passkeys, multiple accounts |
| Chat navigation | Main list, archive, Telegram folders, compact and expanded sidebar, unread and mute presentation | Folder ordering, shared-folder import, richer chat list filters |
| Chat lifecycle | Private chat, basic group, supergroup/channel, secret chat, invite-link join, leave, archive/unarchive | Delete chat/history UX, participants, ownership and member management |
| Contacts | List, search, profile, add, remove, invite through Messages, send contact | Contact notes, birthday suggestions, bulk import and duplicate handling |
| Profile | Name, surname, username, bio and avatar upload | Avatar history/removal, phone change, birthday, emoji status, profile music, default profile tab |
| Messaging | Read, send, reply, forward, edit, delete, pin, drafts, long-text chunking | Scheduled, silent, recurring, send-when-online and link-preview controls |
| Formatting | Selection-based bold, italic, underline, strike, spoiler and monospace through TDLib entity parsing | Link editor, block quotes, expandable quotes, formatted editing and a visual rich-text editor |
| Message types | Photo, album, GIF animation, video, audio, document, sticker, voice, contact, location, poll | Video note, live location, venue, dice and free checklist handling; paid media is read-only/out of scope |
| Reactions | Add and remove ordinary emoji reactions, reaction display | Server-provided free reaction picker, custom emoji display where available and reaction details; paid Star reactions are out of scope |
| Polls | Display, vote and create regular anonymous or multiple-choice polls | Quiz mode, correct-answer explanation, media, option links, closing and scheduling |
| Search | Chat search, public chat lookup, in-chat and global message search, media filters | Public post search, semantic filters, saved searches |
| Topics and comments | Forum topic list, topic history, channel comment threads | Create/edit/close topics, topic tabs, topic permissions and admin actions |
| Media | Per-chat media center with filtering, pagination, download/cancel, Save As, Finder reveal, cache delete and image/video/audio preview | Global download queue, aggregate progress, resumable partial downloads, streaming, speed, quality and playlists |
| Notifications | OS notifications, app-level sound/preview/badge settings and server mute detection | Current mute menu writes only a local override; server-side per-chat mute/sound/preview synchronization and exception management are missing |
| Folders | Read, create, edit, delete and create/reuse a share link on the capable TDLib lane | Reorder, manage invite links, import shared folders, process newly suggested chats, folder limits and recommendations |
| Storage and sessions | Storage statistics, cache cleanup, active sessions and remote termination | Per-chat cache policy, auto-remove periods, session detail and passkey management |
| Secret chats | Creation and normal conversation opening | Dedicated secret-chat information, key visualization, TTL and destructive controls |
| Calls | Navigation destination and prepared placeholder | All voice/video/group-call functionality |
| Bots | Bot chats and ordinary message rendering | Commands, inline mode, callback buttons, reply keyboards, login URLs, Web Apps |
| Administration | Basic group/channel creation and leave | Members, roles, bans, permissions, invite links, join requests, event log, slow mode |
| Stories | Not implemented | Viewing, publishing, reactions, privacy, albums and live stories |
| Business | Not implemented | Quick replies, greeting/away messages, links, locations, hours and connected bots |
| Premium, Stars and gifts | Intentionally not implemented | Read-only rendering or an official-app explanation only; all purchases and monetization actions are prohibited |
| 2025-2026 additions | Not implemented | Checklists, suggested posts, communities, ephemeral group messages, public-post search, rich editor and AI tools |

## Priority Backlog

### P0: reliability before more surface area

1. Server-synchronized per-chat notification settings.
   Telegraphica reads Telegram mute state correctly, but its mute actions are
   local overrides. The next implementation should use TDLib chat notification
   settings where supported and keep the local override only as a documented
   fallback.
2. Formal TDLib capability registry.
   Schema fallbacks are currently spread across the large TDLib client. Add one
   capability object that records the loaded TDLib version and probes support
   for each optional request. UI actions should be hidden or disabled from this
   registry instead of learning support only after an error.
3. Lifecycle and window regression coverage.
   Add automated checks for opening, closing and reopening every retained
   utility window. The folder-window bug is a representative old-AppKit failure.
4. Failure and cancellation consistency.
   Long downloads and TDLib requests need one shared cancellable operation
   model with stale-result protection and consistent status presentation.

## Best Next Implementations

| Order | Feature | User value | Scope | Legacy risk | Why it belongs here |
| ---: | --- | --- | --- | --- | --- |
| 1 | Server-synchronized per-chat notifications | Very high | Medium | Low | Fixes a real mismatch with Telegram and reuses the existing mute menu and server-read path |
| 2 | Chat information and participant list | Very high | Medium | Low/medium | Unlocks member profiles, roles, permissions and the foundation for administration |
| 3 | Scheduled, silent and send-when-online messages | High | Medium | Medium | Extends the existing send pipeline through `messageSendOptions` without a new subsystem |
| 4 | Link-preview controls | High | Small/medium | Medium | Adds disable, URL choice, size and placement to the existing text composer |
| 5 | Global download manager | High | Medium/large | Low | Most download primitives already exist; the missing part is queue/state presentation |
| 6 | Blocked users and privacy rules | High | Medium | Low/medium | Important account control with classic TDLib APIs and little rendering complexity |
| 7 | Invite links, join requests and basic member administration | High for group owners | Large | Medium | TDLib supports the workflow, but permissions and destructive confirmations need careful UX |
| 8 | Quiz polls, video notes, venue, live location and dice | Medium | Medium | Medium | Bounded message types that can reuse current composer and message rendering |
| 9 | Saved Messages organization | Medium/high | Medium | Medium/high | Useful daily feature, but modern topics/tags depend more strongly on the loaded TDLib schema |
| 10 | Bot commands, callback buttons and reply keyboards | Medium/high | Large | Medium/high | High compatibility value, but requires a reusable reply-markup renderer and capability gating |

The first five can be delivered incrementally without changing Telegraphica's
overall architecture. Multiple accounts, calls, Mini Apps and Stories are not
good "next feature" candidates: each introduces a separate session, media or
runtime architecture and carries a much larger regression surface.

### P1: highest daily value

1. Group and channel information with participants.
2. Member roles, permissions, bans and basic invite-link management.
3. Scheduled, silent and send-when-online messages.
4. Link preview enable/disable and preview selection.
5. A global download manager with progress, cancellation and Finder actions.
6. Server notification exceptions and mute duration editor.
7. Blocked users, privacy rules and account TTL.
8. Folder ordering and shared-folder import.
9. Video-note sending and live location.
10. Full quiz polls with explanations.

### P2: useful expansion

1. Bot command menu, callback buttons and reply keyboards.
2. Inline bot mode without a full Mini App runtime.
3. Available-reaction picker, custom emoji and reaction details.
4. Saved Messages topics and tags.
5. Topic creation and administration.
6. Avatar removal/history, birthday and emoji status.
7. Passcode lock for local Telegraphica data.
8. QR login and registration/recovery flows, subject to TDLib-lane support.
9. Multiple accounts.
10. Dice, venue messages and per-chat auto-delete controls.

### P3: large or modern projects

1. Private voice and video calls.
2. Group calls, voice chats and screen sharing.
3. Stories and live stories.
4. Mini Apps runtime and permission model.
5. Business accounts and connected bots.
6. Paid Telegram functionality remains intentionally out of scope.
7. Communities, suggested posts and ephemeral group messages.
8. AI editor, summaries and moderation assistants.

These projects should not block the legacy daily-use client. Paid Telegram
functionality will not be implemented. Calls and Mini Apps in particular need
their own architecture, dependencies and performance budget.

## Recommended Development Sequence

### Stage 1: complete classic Telegram fundamentals

1. Server notification synchronization.
2. Chat information and participant list.
3. Scheduled/silent sending and link-preview controls.
4. Global download manager.
5. Basic member administration and invite links.

These features are broadly useful, fit the native AppKit product and do not
require recreating the newest Telegram product layers.

### Stage 2: account control and richer messages

1. Privacy rules, blocked users and account TTL.
2. Folder ordering and shared-folder import.
3. Quiz polls, video notes, live location, venue and dice.
4. Saved Messages organization.
5. Topic administration.

### Stage 3: bots and multi-account work

1. Bot commands, callbacks and reply keyboards.
2. Inline mode.
3. QR login and recovery.
4. Multiple accounts with isolated TDLib databases and Keychain keys.

### Stage 4: decide which modern Telegram projects are worth the legacy cost

Evaluate Stories, Business, Stars, Mini Apps and calls individually. Do not add
them as one combined milestone.

## TDLib Lane Rules

Every feature must be classified before UI implementation:

| Capability class | Product behavior |
| --- | --- |
| Present on both unified paths | Show the same UI on OS X 10.8-10.13 |
| Present only on the normal path | Keep one codebase, gate the action at runtime and explain the fallback |
| Present only in newer current TDLib | Do not expose the UI until a legacy-loadable newer library is proven |
| Not practical on legacy hardware | Keep it out of the daily-use roadmap or make it an optional Workshop-style module |

Current examples:

- basic chats, messages, contacts, notification settings and classic privacy features should be
  implemented across both paths;
- shared folder links already use a normal-path capability and are disabled on
  the OS X 10.8 fallback;
- scheduling, modern link-preview options, shared-folder import and newer
  message types need runtime request-shape probing before their UI is enabled;
- 2025-2026 Telegram features must not be assumed available merely because
  they exist in current online TDLib documentation.

## Verified Gaps in the Current Code

The following are not guesses based on missing UI. Their TDLib write/read
requests are absent from the current code:

- `setChatNotificationSettings` and notification exception management;
- scheduled-message retrieval and scheduling states;
- chat administrators, supergroup members, member-status changes and bans;
- chat invite-link administration and join-request processing;
- blocked-user lists, privacy rules, account TTL and per-chat auto-delete;
- QR authorization, registration, email authorization and password recovery;
- profile-photo history/removal, phone-number change, birthdays and emoji status;
- video-note, venue, live-location and dice sending;
- custom/paid reactions and server-provided available-reaction selection;
- inline bot queries, callback answers, bot command menus and reply keyboards;
- Saved Messages topics/tags, Stories, Business, Stars and gift workflows.

Conversely, the audit must not list these as missing: contact add/remove/invite,
contact sending, location sending, regular poll creation/voting, album and GIF
sending, media download cancellation, viewport-based read receipts, archive
management, secret-chat creation, profile editing, or chat-folder
create/edit/delete/share. Each has both UI and a TDLib path in this snapshot.

## Engineering Optimization Audit

| Severity | Finding | Evidence | Recommendation |
| --- | --- | --- | --- |
| P1 | TDLib bridge has become a monolith | `TGTDLibClient.m` is over 10,000 lines | Split request families into focused categories or helper objects and keep transport/routing in the core client |
| P1 | Main UI compilation surface is very large | `TGStatusWindowController.m` plus included method groups exceeds 30,000 lines | Move complete settings, media, search and message-action responsibilities into owned controllers |
| P1 | Capability fallbacks are decentralized | Current and legacy request shapes are retried inside many individual methods | Introduce `TGTDLibCapabilities` and make availability a first-class input to UI |
| P1 | UI lifecycle testing is mostly static | Utility windows can regress only after close/reopen on old AppKit | Add a no-network AppKit lifecycle probe for retained windows and their controller ownership |
| P2 | Settings layout is manually repeated | Each section has separate properties, creation, visibility and frame code | Introduce a small settings-section model and shared card-row layout helper |
| P2 | Images can be decoded repeatedly while drawing | Some custom cells load local avatar files inside `drawInteriorWithFrame:` | Add a bounded avatar image cache keyed by path and modification date |
| P2 | Operations use many fixed synchronous wait timeouts | TDLib calls are dispatched off-main but each feature manages its own timeout/status | Add one cancellable operation wrapper with generation tokens and common error mapping |
| P2 | Some user-facing strings remain hard-coded in English | Diagnostics, alerts and transient status strings are not all localized | Move daily-use strings to `TGLocalization`; keep developer-only diagnostics English |
| P3 | Custom view state coverage is incomplete | Native controls provide accessibility, but many icon-only/custom cells rely mainly on tooltips | Add accessibility labels, keyboard actions and focus verification for custom controls |

## Product UI Health

This is a native-product assessment adapted to AppKit rather than a web audit.

| Dimension | Score | Key finding |
| --- | ---: | --- |
| Accessibility | 2/4 | Good native-control foundation, but custom icon cells and keyboard coverage need an explicit pass |
| Performance | 2/4 | Background TDLib work is good; image decoding, large controllers and operation duplication remain |
| Responsive layout | 3/4 | Scrollable settings/drawer and snapped chat sidebar are strong; manual frames still create edge cases |
| Theming | 3/4 | Central theme helpers are widely used, with some hard-coded colors and strings left |
| Product consistency | 3/4 | The app has a coherent native vocabulary; utility windows still vary in lifecycle and polish |
| Total | 13/20 | Acceptable, with reliability and structural work needed before very large new subsystems |

## Next Recommended Feature

After the folder UI correction is verified, implement server-synchronized
per-chat notification settings.

It is the best next step because:

- the user-visible mute state is already loaded and rendered;
- the current local mute menu provides the necessary interaction surface;
- the missing work is bounded to TDLib write methods, fallback behavior and
  state refresh;
- it fixes a real daily inconsistency with official Telegram before adding
  another isolated feature.
