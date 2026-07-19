#!/usr/bin/env python
from __future__ import print_function

import sys


class MockChatState(object):
    def __init__(self):
        self.chats = {}
        self.messages = {}
        self.errors = []

    def apply(self, event):
        if not isinstance(event, dict):
            return False
        event_type = event.get("@type")
        if not event_type:
            return False
        if event_type == "updateNewChat":
            chat = event.get("chat")
            if not isinstance(chat, dict):
                return False
            chat_id = chat.get("id")
            if chat_id is None:
                return False
            self.chats[chat_id] = {
                "id": chat_id,
                "title": chat.get("title") or "Untitled",
                "unread_count": int(chat.get("unread_count") or 0),
            }
            return True
        if event_type == "updateNewMessage":
            message = event.get("message")
            if not isinstance(message, dict):
                return False
            chat_id = message.get("chat_id")
            message_id = message.get("id")
            if chat_id is None or message_id is None:
                return False
            self.messages[(chat_id, message_id)] = {
                "chat_id": chat_id,
                "id": message_id,
                "text": message.get("text") or "",
                "outgoing": bool(message.get("is_outgoing")),
                "read": bool(message.get("is_outgoing") and message.get("is_read")),
                "failed": False,
            }
            if chat_id in self.chats and not message.get("is_outgoing"):
                self.chats[chat_id]["unread_count"] += 1
            return True
        if event_type == "updateMessageSendSucceeded":
            old_chat_id = event.get("old_chat_id")
            old_message_id = event.get("old_message_id")
            message = event.get("message") if isinstance(event.get("message"), dict) else {}
            key = (old_chat_id, old_message_id)
            if key not in self.messages:
                return False
            updated = dict(self.messages.pop(key))
            updated["id"] = message.get("id", old_message_id)
            updated["failed"] = False
            self.messages[(old_chat_id, updated["id"])] = updated
            return True
        if event_type == "updateMessageSendFailed":
            chat_id = event.get("chat_id")
            message_id = event.get("message_id")
            key = (chat_id, message_id)
            if key not in self.messages:
                return False
            self.messages[key]["failed"] = True
            return True
        if event_type == "error":
            self.errors.append(event.get("message") or "unknown error")
            return True
        return False


def check(condition, message, errors):
    if not condition:
        errors.append(message)


def main():
    errors = []
    state = MockChatState()
    check(not state.apply(None), "nil event should be ignored", errors)
    check(not state.apply({}), "empty event should be ignored", errors)
    check(not state.apply({"@type": "updateNewChat", "chat": {}}), "incomplete chat event should be ignored", errors)
    check(state.apply({"@type": "updateNewChat", "chat": {"id": 1, "title": "General"}}), "chat event should apply", errors)
    check(state.chats[1]["title"] == "General", "chat title should be stored", errors)
    check(state.apply({"@type": "updateNewMessage", "message": {"chat_id": 1, "id": 10, "text": "hello"}}), "incoming message should apply", errors)
    check(state.chats[1]["unread_count"] == 1, "incoming message should update unread count", errors)
    check(state.apply({"@type": "updateNewMessage", "message": {"chat_id": 1, "id": -1, "text": "draft", "is_outgoing": True}}), "outgoing temp message should apply", errors)
    check(state.apply({"@type": "updateMessageSendSucceeded", "old_chat_id": 1, "old_message_id": -1, "message": {"id": 11}}), "send success should apply", errors)
    check((1, 11) in state.messages and (1, -1) not in state.messages, "send success should replace temp id", errors)
    check(state.apply({"@type": "updateMessageSendFailed", "chat_id": 1, "message_id": 11}), "send failure should apply", errors)
    check(state.messages[(1, 11)]["failed"], "send failure should mark message failed", errors)
    check(state.apply({"@type": "error", "message": "mock failure"}), "error event should apply", errors)
    check(state.errors == ["mock failure"], "error should be stored", errors)
    check(not state.apply({"@type": "unknownUpdate"}), "unknown event should be ignored", errors)

    if errors:
        print("Mock TDLib event probe failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Mock TDLib event probe passed: chat/message/status/error events and incomplete events.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
