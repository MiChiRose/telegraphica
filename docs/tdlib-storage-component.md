# TDLib storage component

Storage statistics and cache-cleanup request construction live in
`TGTDLibClient+Storage`. The category keeps TDLib schema details out of the
main client while reusing its transport, error and correlation contracts.

The fixture probe verifies fast-statistics aggregation, filtered
`optimizeStorage` requests, normalized chat scope, the inexpensive deleted-file
statistics setting and the post-cleanup refresh without requiring an account.
