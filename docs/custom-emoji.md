# Custom emoji rendering

Telegraphica resolves incoming `textEntityTypeCustomEmoji` entities through
TDLib's `getCustomEmojiStickers` request. The request is routed through the
central capability registry, so a runtime that reports the method as
unsupported, forbidden, or temporarily unavailable is not probed repeatedly.

The legacy renderer deliberately has a narrow, safe scope:

- downloaded static WebP custom emoji are decoded off the main thread and
  displayed as same-size text attachments;
- TGS, WebM, incomplete downloads, malformed server responses, and missing
  files render as the neutral `◇` placeholder instead of an empty message or
  a crash;
- image cache keys include the source path, size, modification time, requested
  decode size, and custom emoji identifier, so replaced files cannot reuse a
  stale bitmap;
- the cache is bounded to 96 images / 12 MB; pending work is capped at 18
  decodes normally and 6 in economy mode;
- a history batch resolves at most 100 identifiers and downloads at most 8
  missing files normally or 3 in economy mode.

Descriptors whose files are still incomplete are not cached permanently. A
later history refresh can therefore retry after TDLib finishes or becomes able
to download the file.

The table view is redrawn when an asynchronous static image becomes available.
Rows are not reloaded because the placeholder and attachment reserve the same
inline footprint.

This support is read/render-only and does not add Premium purchase, paid
reaction, Stars, or other monetization flows.

## Automated coverage

`Tests/custom_emoji_parser_probe.m` consumes
`Tests/Fixtures/custom_emoji_stickers.json` and verifies unique identifier
collection, response ordering fallback, completed-file gating, entity
enrichment, and fail-closed handling of malformed responses.
