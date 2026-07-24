# Mountain Lion Network Access

Telegraphica can ask TDLib to use a proxy before Telegram authorization. This is
intended for OS X 10.8.5 users on networks where Telegram does not answer during
phone-number sign-in.

Create or edit:

`~/Library/Application Support/Telegraphica/tdlib-config.plist`

Keep the existing `api_id` and `api_hash` values intact, then add a `proxy`
dictionary:

```xml
<key>proxy</key>
<dict>
	<key>enabled</key>
	<true/>
	<key>type</key>
	<string>socks5</string>
	<key>server</key>
	<string>127.0.0.1</string>
	<key>port</key>
	<integer>1080</integer>
</dict>
```

Supported proxy types:

- `socks5`: optional `username` and `password`.
- `http`: optional `username`, `password`, and `http_only`.
- `mtproto`: required hexadecimal `secret`.

For one-off testing, the same settings can be passed through environment
variables before launching Telegraphica:

```sh
export TELEGRAPHICA_TDLIB_PROXY_SERVER=127.0.0.1
export TELEGRAPHICA_TDLIB_PROXY_PORT=1080
export TELEGRAPHICA_TDLIB_PROXY_TYPE=socks5
```

Do not put proxy passwords, MTProto secrets, Telegram login codes, or phone
numbers in screenshots or public issue reports.

## Safe Login Mode

The unified Telegraphica app enables safe login mode only when it is actually
running on Mountain Lion. After authorization reaches
`ready`, Telegraphica does not automatically request profile details, live chat
refreshes, or notifications. Chat lists, folders, and messages can still be
loaded manually. This avoids a TDLib 1.8 crash seen while loading poll data from
existing Telegram state on legacy macOS.
In this mode TDLib is also started with `use_message_database` disabled, so it
does not read the local poll/message cache that can abort the library during
startup after login.

On Mavericks and newer systems, the same application bundle keeps the normal
chat/message databases and full background behavior.

For controlled debugging only, safe mode can be disabled before launching:

```sh
defaults write com.michirose.Telegraphica TelegraphicaMountainLionSafeLoginModeDisabled -bool YES
```

Restore the default guarded behavior with:

```sh
defaults delete com.michirose.Telegraphica TelegraphicaMountainLionSafeLoginModeDisabled
```
