# Server reaction catalog

Telegraphica asks TDLib for the reactions available on the selected message with
`getMessageAvailableReactions`. The result is normalized across the current
`top_reactions`, `recent_reactions`, and `popular_reactions` fields and the older
`reactions` field. Duplicates are removed while preserving server priority.

The contextual menu never waits for TDLib. It immediately shows a small set of
emoji known to render on legacy macOS, requests the server catalog in the
background, and uses the cached result the next time the menu opens. The cache
is bounded to 80 messages and is not persisted.

`reactionTypePaid` and entries marked `needs_premium` are never offered.
Custom-emoji identifiers are retained by the parser for future safe rendering,
but Telegraphica does not offer a Premium-only custom reaction action. Existing
custom reactions received with messages remain content that may be rendered by
the normal message pipeline when a compatible asset is available.

An unsupported TDLib request is recorded by the runtime capability registry.
The UI continues using the legacy-safe fallback instead of displaying a raw
TDLib error or retrying on every menu opening.
