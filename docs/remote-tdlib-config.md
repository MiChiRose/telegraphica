# Remote TDLib Config Bootstrap

Telegraphica can start without a bundled Telegram app configuration when the
release build contains a remote bootstrap endpoint URL.

This keeps public GitHub release assets free of embedded Telegram app
credentials while preserving a normal first-run flow for users:

1. Telegraphica starts.
2. It checks `~/Library/Application Support/Telegraphica/tdlib-config.plist`.
3. It checks the built-in runtime configuration, if present.
4. If both are missing, it requests `TelegraphicaRemoteTDLibConfigURL`.
5. If the response contains valid TDLib app credentials, Telegraphica stores a
   local `tdlib-config.plist` and continues to the normal phone login screen.

The endpoint URL is not secret. The returned config is deliberately treated as a
bootstrap convenience, not as a strong secret.

## Build With A Remote Endpoint

Use an HTTPS endpoint:

```sh
TELEGRAPHICA_REMOTE_TDLIB_CONFIG_URL="https://example.workers.dev/v1/tdlib-config" \
TELEGRAPHICA_TDJSON_PATH="/path/to/libtdjson.dylib" \
./build_legacy.sh
```

Do not commit real `api_id` or `api_hash` values to this repository.

## Cloudflare Worker Example

`docs/remote-tdlib-config-worker.js` is a minimal Worker endpoint. Configure
these Worker variables/secrets outside git:

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`

The Worker returns:

```json
{
  "api_id": 12345,
  "api_hash": "0123456789abcdef0123456789abcdef",
  "tdlib_parameters_schema": "auto",
  "use_test_dc": false
}
```

Telegraphica redacts API credential lines from diagnostic logs.
