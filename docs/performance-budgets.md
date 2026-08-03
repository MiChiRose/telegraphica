# Performance budgets

Telegraphica supports one Intel build across OS X 10.8–10.13. Performance work
must therefore be judged on the legacy Macs, not inferred from a modern build.
The numbers below are engineering targets for repeatable HITL measurement; they
are not claims about the current release.

## Budgets

| Scenario | Target |
|---|---:|
| Authorized idle window, no active media or call | under 2% CPU after 30 seconds |
| Open an already-cached chat with 100 visible/history messages | first useful paint under 500 ms |
| Scroll a cached text/photo chat | no main-thread disk decode; no repeated full-table reload per frame |
| Resident memory after opening and closing the same auxiliary window 10 times | no monotonic growth over 10 MB |
| Image cache | bounded by resource policy, with a hard count limit |
| Reopen an already-cached avatar/thumbnail | no file decode when its source version and display size are unchanged |

Use Activity Monitor and the diagnostic log on the old Mac. Record the OS,
hardware, source revision, selected theme, chat type and whether media was
already cached. Compare like with like; animated media and active calls are
separate scenarios.

## Image-loading contract

`TGMediaImageLoader` owns the shared bounded image cache. File keys include the
standardized path, requested display/decode size, file number, byte size and
modification date. Replacing a downloaded file therefore cannot silently reuse
the previous thumbnail.

UI that can tolerate deferred images should request a cached thumbnail first,
then use `TGLoadImageThumbnailFromFileAsync`. Decode runs on a background queue;
the completion is delivered on the main thread. The returned token is
cancellable, and controllers must cancel outstanding tokens when their content
generation changes or they are destroyed.

The reaction/viewer list and Saved Messages rows use this path. Saved Messages
also reserves the thumbnail rectangle while loading, so late images do not
shift text horizontally.

## Remaining manual measurements

- baseline and optimized chat-open timings on both the 10.8 fallback and the
  10.9–10.13 normal path;
- Instruments/Time Profiler samples for the heaviest visual themes;
- scrolling FPS with photos, stickers, custom emoji and link previews;
- repeated login, profile, media center, privacy, folder and call-window cycles;
- network and memory behavior while large media downloads are cancelled.

These checks require real legacy hardware and authorized Telegram data. They
remain HITL work and are deliberately not faked by the fast local probes.
