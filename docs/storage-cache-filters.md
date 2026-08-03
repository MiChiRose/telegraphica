# Filtered storage cleanup

The Storage Usage window can ask TDLib to remove downloaded cache entries by
data type and, when a chat is currently selected, by chat.

Available data filters mirror Telegraphica's automatic-download categories:
all files, photos, videos (including video notes and animations), documents,
voice messages, and audio files. The scope is either all chats or the current
chat. A destructive confirmation repeats both selected filters.

The host never deletes TDLib files directly. It builds the legacy-compatible
`optimizeStorage` filter, normalizes and deduplicates chat identifiers, limits
the identifier list, and lets TDLib preserve its database invariants. Telegram
cloud messages and files saved separately in Downloads are not affected.
