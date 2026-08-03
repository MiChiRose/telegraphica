# Asynchronous inline GIF loading

Inline GIF validation, file I/O and `NSImage` creation run on a serial background
decode queue. The message-list update path creates only a lightweight placeholder
and spinner, then applies the prepared image on the main thread.

The loader rejects animations outside the shared decoded-byte and frame-count
budgets before AppKit receives them. Its bounded cache key includes the canonical
path, file identity, size and modification timestamp. Leaving the viewport or
closing the owning window cancels delivery so stale completions cannot update a
discarded playback view.

This path is shared by the unified OS X 10.8–10.13 target and does not change
the verified audio/video call transport.
