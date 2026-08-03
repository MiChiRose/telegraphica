# TDLib message search component

Message-search request construction, schema fallbacks, response validation and
pagination now live in `TGTDLibClient+Search`. The main `TGTDLibClient` remains
the owner of transport and message transformation; the search category calls
those focused private contracts instead of duplicating request routing.

The fixture-style request probe covers global and per-chat request types,
bounded limits, filter mapping, thread-first topic search, anchor message IDs,
and next-offset propagation without a Telegram account.
