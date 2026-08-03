# Media download recovery

Telegraphica persists a bounded, property-list-safe snapshot of the download manager. Records that were queued or downloading when the application stopped are restored as interrupted work and restarted only after TDLib reports the authorization state `ready`.

The resumed request keeps the TDLib `file_id` and requests the complete range. TDLib can therefore continue its own local cached transfer instead of Telegraphica creating a second partial-file format. At most 100 sanitized queue records are retained; callbacks from the previous process are never restored.

Resource settings treat voice/audio messages as a separate auto-download category. Economy mode keeps voice messages enabled under the shared size limit while disabling automatic video and document downloads. Photos, videos, documents, and voice messages remain independently configurable.

## Verification

- `Tests/download_queue_store_probe.m` checks invalid-record rejection, interrupted-state recovery, `file_id` retention, and property-list safety.
- `Tests/core_logic_probe.m` checks the independent voice policy and economy-mode behavior.
- `./scripts/run_tests.sh` runs both probes with the OS X 10.8 deployment target.
