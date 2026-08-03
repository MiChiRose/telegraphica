# Rich-text entities

Telegraphica keeps Telegram formatting as TDLib `formattedText` objects. Entity offsets and lengths are treated as UTF-16 code-unit indexes, matching TDLib and `NSString`.

## Sending and rendering

- The composer supports bold, italic, underline, strikethrough, spoiler, inline code, text links, block quotes, and expandable block quotes through the text selection menu.
- Markdown is parsed by the loaded TDLib. Telegraphica validates the returned ranges before putting them in a request.
- Received block and expandable quotes use a visible leading rule and inset. Code uses the system fixed-pitch font; spoilers have a distinct concealed background.
- Invalid entity types, negative ranges, out-of-bounds ranges, and ranges that split a UTF-16 surrogate pair or composed character sequence are discarded safely.

## Editing

The message editor rebases existing entities across the smallest changed span:

- entities in the unchanged prefix stay in place;
- entities in the unchanged suffix shift by the UTF-16 delta;
- an entity enclosing the whole edit expands or contracts with it;
- an entity intersected ambiguously by the edit is removed instead of sending a corrupt range.

This preserves untouched links and formatting while allowing ordinary text edits. Sending or editing a newly formatted selection still uses TDLib's parser and therefore follows the active lane's capability result.

## Test coverage

`Tests/formatted_text_codec_probe.m` covers surrogate-pair validation, invalid partial emoji ranges, entity shifting after insertion, safe removal of touched formatting, enclosing quote expansion, and request-object construction.
