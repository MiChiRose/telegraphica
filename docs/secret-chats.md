# Secret chats

Telegraphica treats a secret chat as a dedicated TDLib conversation type, not as a normal private chat.

## Supported controls

- The chat header opens a dedicated information window for secret chats.
- `getSecretChat` supplies the state, direction, protocol layer, and key hash.
- The first 36 key-hash bytes are rendered as the official 12 × 12 four-color visualization. The first 32 bytes are also shown as a selectable hexadecimal fingerprint.
- Per-chat self-destruct time uses `setChatMessageAutoDeleteTime`. Secret chats expose short durations in addition to the normal chat choices.
- Closing uses `closeSecretChat` and always requires explicit confirmation.
- History deletion uses `deleteChatHistory` with removal from the chat list and revocation requested. It has a separate destructive confirmation.

Key material is kept in memory for presentation only. It must never be written to diagnostic logs, defaults, or cache files.

## Compatibility

The UI is shared by the unified OS X 10.8–macOS 10.13 build. Runtime capability results from the loaded TDLib decide whether self-destruct controls are enabled; no OS-specific product fork is created.
