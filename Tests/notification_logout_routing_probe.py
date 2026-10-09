#!/usr/bin/env python
from __future__ import print_function

import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))


def read_source(path):
    with open(os.path.join(ROOT, path), "rb") as handle:
        return handle.read().decode("utf-8")


def body_after(source, marker):
    start = source.index("{", source.index(marker))
    depth = 1
    position = start + 1
    while depth:
        if source[position] == "{":
            depth += 1
        elif source[position] == "}":
            depth -= 1
        position += 1
    return source[start + 1:position - 1]


logout = read_source("Sources/UI/TGStatusWindowController+SessionLogout.inc")
completion = read_source("Sources/UI/TGStatusWindowController+LogoutCompletion.inc")
call = "[self resetNotificationDeliveryAfterLogout];"
assert logout.count(call) == 0 and completion.count(call) == 1, "logout cleanup must have exactly one owning call"
confirmed = body_after(completion, "if (logoutSummary)")
assert call in confirmed, "failed or cancelled logout must never remove message notifications"
assert confirmed.index(call) < confirmed.index("self.client ="), "departed owner must clear entries before client replacement"
assert completion.index("if (self.client != client) { return; }") < completion.index("if (logoutSummary)"), "stale logout owner must not change the replacement account"
callback = body_after(logout, "dispatch_async(dispatch_get_main_queue()")
assert "[self applyLogoutSummary:logoutSummary errorMessage:logoutErrorMessage owner:client];" in callback
assert "[logoutSummary release];" in callback and "[logoutErrorMessage release];" in callback and "[client release];" in callback, "logout delivery must release copied results and retained owner on every branch"
assert logout.split("- (void)deleteLocalData:")[0].count("[client release];") == 1, "captured owner must stay retained until main-thread delivery"

controller = read_source("Sources/UI/TGStatusWindowController.m")
for method in ("- (void)setClient:", "- (void)setCurrentAuthState:"):
    body = body_after(controller, method)
    assert "resetNotificationDeliveryAfterLogout" not in body, "transient client/auth recovery must retain system entries"

replacement = body_after(controller, "- (void)setClient:")
changed_owner = body_after(replacement, "if (_client != client)")
cache_clear = "[self.notificationChatInfoByChatID removeAllObjects];"
assert cache_clear in changed_owner, "replacement owner must release stale enrichment data and pending tokens"
assert changed_owner.index(cache_clear) < changed_owner.index("_client ="), "invalidate enrichment before attaching replacement client"

print("Notification logout routing probe passed: confirmed explicit logout only, transient recovery preserves deliveries.")
