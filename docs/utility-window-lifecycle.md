# Utility window request lifetime

Retained utility windows use `TGUtilityWindowLifetime` to advance a generation
when a window opens, starts a new operation, or closes. Background completions
may update AppKit only while their generation is current and the presentation
is active.

The storage-usage window is the first migrated owner. Its idempotent summary
read uses `TGTDLibOperation`, is cancelled when superseded or closed, and is
delivered once on the main thread. Destructive cache cleanup is never retried;
if the window closes, the TDLib operation may finish safely but its late UI
callback is suppressed. Reopening begins a fresh summary request.
