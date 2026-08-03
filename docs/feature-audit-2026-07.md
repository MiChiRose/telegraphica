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

This boundary is now enforced during every legacy build by
`scripts/check_free_feature_policy.py`. The check rejects Telegram payment,
Premium, Stars, gift, boost, paid-message and giveaway request types while
allowing read-only rendering and neutral official-client explanations.

## Free-feature roadmap implementation

The July roadmap batch is implemented on `feature/free-telegram-roadmap`:

1. per-chat Telegram notification settings and exception management;
2. chat information, members, invitations, roles, restrictions and bans;
3. silent, scheduled and send-when-online messages, link-preview controls, and
   scheduled-message management;
4. a shared Download Manager with progress, cancellation, retry, Save As and
   Finder reveal;
5. privacy rules, blocked users, account inactivity TTL and message
   auto-delete;
6. invite-link creation/revocation, join-request approval, event log and slow
   mode;
7. quiz polls, video notes, venues, live locations and dice;
8. Saved Messages topics, topic history and pinning within the free server
   limit;
9. bot commands and inline results;
10. callback buttons, text reply keyboards and safely confirmed Login URLs.

Premium-only Saved Messages tag search/editing, paid inline results, payment
buttons, Mini Apps and automatic sharing of phone/location through bot buttons
remain deliberately disabled.

## Current Coverage

| Area | Current status | Important remaining work |
| --- | --- | --- |
| Authorization | Phone number, code, 2FA password, session reuse, Keychain database key, logout | QR login, registration, email codes, recovery, passkeys, multiple accounts |
| Chat navigation | Main list, archive, Telegram folders, compact and expanded sidebar, unread and mute presentation | Folder ordering, shared-folder import, richer chat list filters |
| Chat lifecycle | Private chat, groups/channels, secret chat, invite-link join, leave, archive, chat information, participants and member-role management | Delete chat/history UX and ownership transfer |
| Contacts | List, search, profile, add, remove, invite through Messages, send contact | Contact notes, birthday suggestions, bulk import and duplicate handling |
| Profile | Name, surname, username, bio and avatar upload | Avatar history/removal, phone change, birthday, emoji status, profile music, default profile tab |
| Messaging | Read, send, reply, forward, edit, delete, pin, drafts, long-text chunking, silent/scheduled/send-when-online and link-preview controls | Recurring messages and richer scheduled-media editing |
| Formatting | Selection-based bold, italic, underline, strike, spoiler and monospace through TDLib entity parsing | Link editor, block quotes, expandable quotes, formatted editing and a visual rich-text editor |
| Message types | Photo, album, GIF animation, video, audio, document, sticker, voice/video notes, contact, location/live location, venue, dice and polls | Free checklist handling; paid media is read-only/out of scope |
| Reactions | Add and remove ordinary emoji reactions, reaction display | Server-provided free reaction picker, custom emoji display where available and reaction details; paid Star reactions are out of scope |
| Polls | Display, vote, regular polls and quiz creation with correct-answer explanation | Poll media, option links, closing and scheduling |
| Search | Chat search, public chat lookup, in-chat and global message search, media filters | Public post search, semantic filters, saved searches |
| Topics and comments | Forum topic list, topic history, channel comment threads | Create/edit/close topics, topic tabs, topic permissions and admin actions |
| Media | Per-chat media center plus shared Download Manager, filtering, pagination, progress, retry/cancel, restart recovery through TDLib file IDs, Save As, Finder reveal, cache delete, preview/playback, independent 1x/1.5x/2x audio/video speeds, optional sequential voice/audio playback, and separate photo/video/document/voice auto-download controls | Progressive playback, quality, broader playlists and per-chat/type cache cleanup |
| Notifications | OS notifications, app settings, server mute state, per-chat mute/sound/preview synchronization and exception management | Scheduled notification profiles and richer sound selection |
| Folders | Read, create, edit, delete, drag ordering, shared-folder import, multiple invite-link management, suggested/new-chat processing, recommendations and server-reported limits on the capable TDLib lane | Per-link selection of a subset of shareable chats still uses Telegram's complete eligible set when creating a new link |
| Storage and sessions | Storage statistics, cache cleanup, active sessions and remote termination | Per-chat cache policy, auto-remove periods, session detail and passkey management |
| Privacy | Server privacy rules, blocked users, account inactivity TTL and per-chat/default auto-delete | Passcode lock, exception editor and account deletion UX |
| Secret chats | Creation and normal conversation opening | Dedicated secret-chat information, key visualization, TTL and destructive controls |
| Calls | Navigation destination and prepared placeholder | All voice/video/group-call functionality |
| Bots | Commands, inline results, callback buttons, text reply keyboards and confirmed Login URLs | Web Apps and explicit opt-in flows for personal-data keyboard buttons |
| Administration | Members, roles, restrictions/bans, invite links, join requests, event log and slow mode | Full permission matrix, ownership transfer and bulk moderation |
| Saved Messages | Topics, topic history, tags display and free-limit pinning | Premium tag search/editing is intentionally unavailable |
| Stories | Not implemented | Viewing, publishing, reactions, privacy, albums and live stories |
| Business | Not implemented | Quick replies, greeting/away messages, links, locations, hours and connected bots |
| Premium, Stars and gifts | Intentionally not implemented | Read-only rendering or an official-app explanation only; all purchases and monetization actions are prohibited |
| 2025-2026 additions | Not implemented | Checklists, suggested posts, communities, ephemeral group messages, public-post search, rich editor and AI tools |

## Priority Backlog

### P0: reliability before more surface area

1. Formal TDLib capability registry.
   Schema fallbacks are currently spread across the large TDLib client. Add one
   capability object that records the loaded TDLib version and probes support
   for each optional request. UI actions should be hidden or disabled from this
   registry instead of learning support only after an error.
2. Lifecycle and window regression coverage.
   Add automated checks for opening, closing and reopening every retained
   utility window. The folder-window bug is a representative old-AppKit failure.
3. Failure and cancellation consistency.
   Long downloads and TDLib requests need one shared cancellable operation
   model with stale-result protection and consistent status presentation.

### P1: highest daily value

1. Folder ordering, shared-folder import and invite-link management are now implemented; retain them in the OS X 10.9/10.13 lifecycle HITL matrix.
2. Topic creation/edit/close and topic permissions.
3. Passcode lock for local Telegraphica data.
4. Profile-photo history/removal and phone-number change.
5. Server-provided free-reaction picker and custom emoji display.
6. Secret-chat key visualization, TTL and destructive controls.
7. Rich-text link editor, quotes and formatted editing.
8. Delete-history UX with explicit destructive confirmations.

### P2: useful expansion

1. QR login and registration/recovery flows, subject to TDLib-lane support.
2. Multiple accounts with isolated databases and Keychain keys.
3. Poll closing/scheduling and poll media.
4. Free checklist support where the loaded TDLib lane exposes it.
5. Download streaming, playback speed and playlists.
6. Stories viewing only, after a separate legacy-performance prototype.

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
- scheduling, modern link-preview options and newer
  message types need runtime request-shape probing before their UI is enabled;
- 2025-2026 Telegram features must not be assumed available merely because
  they exist in current online TDLib documentation.

## Verified Gaps in the Current Code

The following are not guesses based on missing UI. Their TDLib write/read
requests remain absent after the free-feature roadmap:

- QR authorization, registration, email authorization and password recovery;
- profile-photo history/removal, phone-number change, birthdays and emoji status;
- custom/paid reactions and server-provided available-reaction selection;
- Stories, Business and free checklist workflows;
- Mini Apps and automatic phone/location sharing from reply keyboards;
- multiple accounts, passkeys and passcode lock.

The audit must not list notification synchronization, scheduled-message
retrieval, member administration, invite links/join requests, blocked-user and
privacy rules, video notes/venue/live location/dice, bot commands/inline
queries/callbacks/reply keyboards/Login URLs, or Saved Messages topics as
missing: each now has both UI and a TDLib path.

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
| P2 | Some auxiliary image surfaces can still decode while drawing | Chat/message avatars, message media, link-preview cards, and static sticker picker thumbnails now use bounded async prefetch plus cache-only drawing; auxiliary utility views still need the same audit | Extend the shared loader contract to remaining auxiliary image surfaces |
| P2 | Operations use many fixed synchronous wait timeouts | TDLib calls are dispatched off-main but each feature manages its own timeout/status | Add one cancellable operation wrapper with generation tokens and common error mapping |
| P2 | Some user-facing strings remain hard-coded in English | Diagnostics, alerts and transient status strings are not all localized | Move daily-use strings to `TGLocalization`; keep developer-only diagnostics English |
| P3 | Custom view state coverage is incomplete | Native controls provide accessibility, but many icon-only/custom cells rely mainly on tooltips | Add accessibility labels, keyboard actions and focus verification for custom controls |

## Product UI Health

This is a native-product assessment adapted to AppKit rather than a web audit.

| Dimension | Score | Key finding |
| --- | ---: | --- |
| Accessibility | 2/4 | Good native-control foundation, but custom icon cells and keyboard coverage need an explicit pass |
| Performance | 3/4 | Main chat image drawing and TDLib operations are now asynchronous and bounded; secondary surfaces and large controllers remain |
| Responsive layout | 3/4 | Scrollable settings/drawer and snapped chat sidebar are strong; manual frames still create edge cases |
| Theming | 3/4 | Central theme helpers are widely used, with some hard-coded colors and strings left |
| Product consistency | 3/4 | The app has a coherent native vocabulary; utility windows still vary in lifecycle and polish |
| Total | 13/20 | Acceptable, with reliability and structural work needed before very large new subsystems |

## Next Recommended Feature

After HITL verification of this roadmap batch, continue the media and
performance phase while retaining the completed `TGTDLibCapabilities` registry
and advanced-folder gates as the model for newer TDLib features.

It is the best next step because:

- the combined OS X 10.8–10.13 build must keep a single code path while safely
  gating schema differences;
- the current feature set contains several intentional modern/legacy request
  fallbacks that should be visible to the UI before a user presses an action;
- capability-driven controls prevent unsupported actions from leaving
  half-open utility windows or raw TDLib errors;
- folder import and topic administration can then be added without scattering
  more version checks through large controllers.
