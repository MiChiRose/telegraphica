# Accessibility and keyboard foundation

Telegraphica uses the legacy AppKit accessibility override API available on the
unified OS X 10.8–macOS 10.13 lane. `TGAccessibilitySupport` assigns roles,
localized labels, optional help and live enabled/selected values to custom
icon-only buttons without relying on newer accessibility setters.

The main window exposes its chat, message and search tables as lists. Primary
navigation, composer, chat-header and back/cancel controls receive VoiceOver
names even when their visual title is intentionally empty.

Custom chat cells expose a single readable description containing the chat
name, kind, unread count, muted state and pinned state. Message cells expose
direction/sender, text or media kind, sending/read/failure state, pinned state,
reactions and unread separators. The visual layout remains unchanged.

Keyboard routing includes Command+N for a new chat, Command+K for quick chat
navigation, Command+F for current-chat search, Command+Shift+F for global
search, Command+, for settings and Escape for the active overlay/navigation
layer. Native AppKit continues to own Command+W and standard text editing.

`Tests/accessibility_support_probe.m` verifies the legacy VoiceOver attribute
contract without requiring a running application session. Static project tests
also protect the main-window wiring and keyboard shortcuts from regressions.
