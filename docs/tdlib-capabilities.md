# TDLib capability registry

`TGTDLibCapabilities` is the single runtime source for feature availability in
the unified OS X 10.8–10.13 application. It does not replace normal TDLib
authorization or per-chat permission checks. It records what the currently
loaded TDLib lane has demonstrated and keeps that result cheap to read from UI
code.

## Runtime identity

The registry records:

- the selected runtime lane (`mountain-lion-fallback`, `mavericks-or-newer`, or
  `unknown`);
- the loaded tdjson path;
- TDLib version, source commit, and MTProto layer when the library exposes the
  corresponding options;
- the packaged TDLib version from
  `TelegraphicaLegacyBinaryManifest.tsv` when an old library cannot expose its
  version through `getOption`.

No probe changes authorization state, user data, chats, or messages. Feature
results are learned from safe requests already made by the application and are
cached under a lock for synchronous UI reads.

## States

Support and the last request outcome are deliberately separate:

- `supported`: TDLib accepted the request, or rejected it because this account
  or chat lacks permission. The latter records `forbidden` as the last outcome
  without globally disabling the feature.
- `unsupported`: TDLib reported an unknown/unsupported request or schema.
- `temporarily_unavailable`: a network, timeout, flood-control, or server error
  occurred. This does not overwrite earlier support knowledge.
- `unknown`: no safe request has established support yet.

UI code should read `supportStateForCapability:`,
`lastProbeStateForCapability:`, and `reasonForCapability:`. A temporary failure
must be presented as retryable; it must not be described as a missing feature.

## Declared capabilities

The initial registry covers QR/email/registration/recovery authorization,
available reactions, custom emoji, modern entities, folder management and
sharing, forum topics, secret-chat TTL, streaming/resume, recurring messages,
checklists, HD photos, voice trimming, Stories viewing, group calls, and Mini
Apps. New capabilities must be added centrally with fixture coverage rather
than inferred from a filename or duplicated in view controllers.

## Verification

`Tests/tdlib_capabilities_probe.m` uses artificial TDLib responses to verify
success, unsupported schema, forbidden access, and temporary failure. It is
compiled and run by `./scripts/run_tests.sh` with manual reference counting and
the OS X 10.8 deployment target.
