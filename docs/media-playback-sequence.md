# Sequential audio playback

Telegraphica can optionally continue from a completed voice or audio message to
the next playable audio message in the same visible chat. The preference is in
Settings → Resources and is disabled by default, so existing playback behavior
does not change without the user's choice.

The sequence helper is intentionally conservative:

- it never crosses into another chat;
- it skips video and video-note messages;
- it stops when the source message is no longer part of the visible chat;
- downloaded and not-yet-downloaded audio use the existing playback/download
  path, including the OS X 10.8-safe Opus preparation fallback;
- closing the player clears the sequence source and stops advancement.

Playback speed remains independent for audio and video and applies to every
item opened by the sequence.
