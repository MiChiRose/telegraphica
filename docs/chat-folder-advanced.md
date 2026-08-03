# Advanced chat folders

Telegraphica keeps one chat-folder implementation for the unified OS X
10.8–10.13 application. Basic local folder editing and ordering remain
available through the legacy request shapes. Shared-folder operations are
runtime-gated by `TGTDLibCapabilities` and are intentionally unavailable when
the Mountain Lion fallback TDLib is loaded.

On a capable TDLib lane the folder editor opens a separate links and
suggestions window. It supports:

- listing, copying, creating, renaming and deleting every invite link for the
  selected folder;
- accepting all newly suggested chats or dismissing the current suggestions;
- viewing and adding Telegram-recommended folder definitions;
- displaying the folder, chosen-chat and invite-link limits reported by the
  server options instead of embedding guessed constants.

Every mutation runs off the main thread and refreshes the authoritative TDLib
state after completion. Closing the utility window advances its generation
token, so late background results are ignored. Deleting an invite link requires
explicit confirmation and never deletes the folder or its chats.

## Capability behavior

- Mountain Lion fallback: the share action is disabled with a localized
  explanation.
- Capability explicitly unsupported: the client returns a normalized error and
  does not send another request.
- Unknown capability on the normal lane: Telegraphica performs the requested
  safe probe once through normal request routing; its result updates the shared
  capability registry.
- Missing limit options: the UI states that limits are unavailable. It never
  suggests Premium acquisition or a purchase path.

The fixture probe in `Tests/chat_folder_support_probe.m` covers malformed invite
links, string/numeric chat identifiers, recommended folder conversion and
fail-closed option parsing without using real Telegram identifiers.

