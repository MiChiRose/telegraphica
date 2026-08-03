# TDLib update and rollback guide

Telegraphica ships one application for OS X 10.8–10.13 and may bundle two
runtime-compatible tdjson libraries inside that application:

| Runtime lane | Host OS | Initial status | Storage |
|---|---|---|---|
| `mountain-lion-fallback` | OS X 10.8 | verified legacy until replaced | Mountain Lion-specific TDLib database/files directories |
| `mavericks-or-newer` | OS X 10.9–10.13 | verified current or experimental candidate | Mavericks-and-newer TDLib database/files directories |

The application target, source tree, and release artifact remain unified. A
TDLib candidate is a runtime component, not a second Telegraphica product.

## Building a candidate

1. Use an exact TDLib tag or a source checkout with a stable commit.
2. Run `scripts/build_tdlib_legacy.sh` with the appropriate deployment target.
3. Leave `TDLIB_RELEASE_STATUS=experimental` until real-machine validation is
   complete. The build produces:

   - `stage/Frameworks/libtdjson.dylib`;
   - `stage/TDLibBuildMetadata.tsv`;
   - `stage/TDLibBuildMetadata.exports.txt`.

The metadata records the project version, source tag and commit, MTProto layer,
architecture, minimum OS, install name, binary digest, and ABI-export digest.
The build fails if the pointer-based tdjson functions used by Telegraphica are
not exported.

## Candidate validation

For each lane:

1. Run `scripts/check_tdjson_legacy.sh` and
   `scripts/check_tdlib_build_metadata.sh`.
2. Build the same application revision with both runtime libraries bundled.
3. Run `scripts/check_release_bundle_legacy.sh` so every nested Mach-O is
   checked for x86_64, `LC_VERSION_MIN_MACOSX`, absence of
   `LC_BUILD_VERSION`, portable dependencies, and matching metadata/ABI hashes.
4. Validate login restart, chat/message history, sending, media, folders, and
   calls on the applicable real old Mac. A 10.9+ candidate does not replace the
   10.8 fallback result, and vice versa.
5. Promote metadata to `verified` only after recording the tested source
   revision, application revision, OS build, and result.

Capability decisions still come from safe runtime probes. A newer version or
MTProto layer is useful diagnostic evidence but never by itself enables a UI
action.

## Database safety

- Never point the Mountain Lion fallback and Mavericks/newer runtime at the
  same TDLib database directory.
- Never test a downgrade against the only copy of a database already opened by
  a newer experimental TDLib.
- Before the first launch of a candidate, quit Telegraphica and make a
  recoverable copy of that lane's TDLib database directory. Do not copy or
  publish the Keychain encryption key with build artifacts.
- Candidate failure must not trigger automatic deletion, reinitialization, or
  migration of the verified database. Prefer a separate diagnostic application
  support root when schema compatibility is uncertain.

## Rollback

1. Quit Telegraphica and retain the failed candidate's logs and metadata, with
   diagnostics redacted.
2. Restore the last HITL-verified tdjson binary and its matching metadata and
   ABI export list. Do not mix a binary from one build with metadata from
   another; the bundle audit rejects the digest mismatch.
3. Restore the pre-candidate database copy if the candidate opened the database
   and the older TDLib cannot read it. Never repeatedly alternate incompatible
   libraries against the same live directory.
4. Rebuild the unified app, run the full bundle audit, then verify login and a
   read-only chat load before allowing message writes.
5. Keep unsupported candidate-only features disabled through
   `TGTDLibCapabilities`; do not raise the deployment target or remove the
   verified legacy library to make an update appear successful.

## Existing binaries without provenance metadata

`build_legacy.sh` can import an already verified historical dylib. When no
sidecar is available it creates a `legacy-import` record with unknown source
fields but exact binary and ABI hashes. This preserves the known-good library
without inventing provenance. Such a record must not be presented as a newly
verified TDLib build.
