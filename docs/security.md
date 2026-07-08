# Telegraphica Security Notes

Telegraphica is an experimental unofficial Telegram client. It handles account
authorization, a long-lived Telegram session, local chat metadata, media cache,
and diagnostic logs. Treat all of those as sensitive.

## Trust Boundaries

Assets:

- Telegram session/auth material managed by TDLib.
- TDLib database encryption key.
- `api_id` and `api_hash`.
- Phone number, login code, and 2FA password.
- Local chat metadata, message previews, downloaded media, thumbnails, and
  filenames.
- Logs, crash reports, and support bundles.

Boundaries:

- User UI to app.
- App to TDLib JSON API.
- TDLib to Telegram datacenters/proxies.
- App to Keychain.
- App to filesystem caches/logs.

TDLib should own MTProto networking and storage mechanics. Telegraphica should
not implement MTProto crypto directly.

## Required Controls

### API Credentials

Use a dedicated app registration from `my.telegram.org`. Do not ship sample
credentials and do not commit real values. A desktop binary cannot keep
`api_hash` truly secret, so treat it as protected configuration rather than a
perfectly hidden secret.

### Login

Never persist login codes or 2FA passwords. Use secure text entry for login code
and password input. Clear input fields immediately after submission. Redact phone
numbers, codes, passwords, and auth errors from logs and crash messages.

### Session And Database

Set explicit TDLib paths:

- `~/Library/Application Support/Telegraphica/tdlib/`
- `~/Library/Caches/Telegraphica/tdlib-files/`

Never let TDLib use the current working directory. Generate a random TDLib
database encryption key and store only that key in Keychain. Do not derive it
from the phone number, `api_hash`, username, or a constant.

### Keychain

Use a Telegraphica-specific Keychain service name. Store only the TDLib database
encryption key and future local app secrets. Delete items on logout/reset. Do
not enable synchronizable Keychain items unless the product deliberately designs
for multi-device secret sync.

### Logs

Diagnostics must be opt-in. Release builds should keep TDLib verbosity low.
Never log:

- `api_hash`
- phone number
- login code
- 2FA password
- database encryption key
- message bodies
- downloaded media paths unless redacted

Do not log or display raw `getMe`/`getChats`/`getChat` JSON. `getMe` can
include `phone_number` and profile fields; chat APIs expose chat IDs, titles,
membership metadata, unread counts, and eventually message previews. Probe and
diagnostic output should omit phone numbers and secret fields and prefer generic
success/counts. Showing chat titles in the local UI is allowed for the signed-in
user, but screenshots of that table are sensitive and should not be shared
publicly.

Telegraphica's logger currently keeps a bounded in-memory log and only writes a
file when `TELEGRAPHICA_DEBUG`, `TELEGRAPHICA_DEV_LOGS`, or the
`TelegraphicaDebugEnabled` default is enabled.

### Media And Cache

Downloaded media, thumbnails, profile images, and filenames are sensitive. Keep
cache data under `~/Library/Caches/Telegraphica/`, not Desktop or Documents.
Add explicit "Clear media cache" and "Remove local data" controls before media
download becomes part of the MVP.

### Logout And Data Deletion

Provide two distinct actions later:

- Log out: call TDLib `logOut` when online.
- Remove local data: close/destroy TDLib state, delete app support/cache/logs,
  and remove Keychain items.

If offline local deletion cannot revoke the server-side session, tell the user
to revoke the session from an official Telegram client.

### Network

Do not bypass TDLib security checks. If proxy support is added, make it explicit
and warn that proxies can observe connection metadata. Keep system clock issues
visible because MTProto message IDs are time-sensitive.

### Telegram Terms

Preserve Telegram semantics for user-visible actions: no hidden reads, ghost
mode, counter manipulation, invite spam, scraping, or self-destruct bypass. Do
not use official Telegram branding/logo/assets.

## Severity Guide

Critical:

- Leaking login code, 2FA password, TDLib DB key, or session material.
- Sending/deleting messages without user consent.
- Custom MTProto crypto that skips validation.

High:

- World-readable TDLib database or media cache.
- Verbose production logs containing message content.
- Broken logout/reset leaving local secrets.

Medium:

- Phone number, chat IDs, usernames, or local media paths in logs/crashes.
- Chat titles or unread metadata in logs/crashes/screenshots shared outside the
  local validation loop.
- Stale media cache without deletion controls.
- Unclear unofficial-client disclosure.

Low:

- Window state, UI preferences, generic app version/device metadata.

## Sources

- Telegram application/API ID: https://core.telegram.org/api/obtaining_api_id
- Telegram API Terms of Service: https://core.telegram.org/api/terms
- Telegram user authorization: https://core.telegram.org/api/auth
- MTProto overview: https://core.telegram.org/mtproto
- MTProto security guidelines: https://core.telegram.org/mtproto/security_guidelines
- TDLib README: https://github.com/tdlib/td
- TDLib JSON API: https://core.telegram.org/tdlib/docs/td__json__client_8h.html
- TDLib `setTdlibParameters`: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_tdlib_parameters.html
- TDLib `checkDatabaseEncryptionKey`: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1check_database_encryption_key.html
- TDLib `setDatabaseEncryptionKey`: https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1set_database_encryption_key.html
