# Reaction users

Telegraphica shows **Who reacted** only when the message-provided
`can_get_added_reactions` permission is true. The data path uses
`getMessageAddedReactions`, excludes paid reactions, resolves both user and chat
senders, and limits each page to 100 entries.

The request is an idempotent cancellable `TGTDLibOperation`. Unsupported TDLib
lanes are recorded by `TGTDLibCapabilities`; raw TDLib errors are not exposed in
the message menu. Custom emoji that cannot yet be rendered use a stable neutral
placeholder without logging their identifiers.
