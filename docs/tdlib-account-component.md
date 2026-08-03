# TDLib account component

Current-user profile operations and active-session management live in
`TGTDLibClient+Account`. The focused category reuses the main client's
authorization state, request transport, formatted-text parser and avatar
materialization helpers without owning login, Keychain or session storage.

The account-free fixture probe covers profile reads, name/username/bio updates,
static profile-photo requests, active-session normalization and explicit
session termination. This keeps the moved TDLib request contract testable
without connecting to a Telegram account.
