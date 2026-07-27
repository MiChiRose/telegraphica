#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
SOURCES = os.path.join(ROOT, "Sources")

# Telegraphica may display already-received paid content and explain that an
# action belongs in the official Telegram client. It must never call TDLib
# commerce, purchase, paid-reaction, gift, boost, or giveaway APIs.
FORBIDDEN_TDLIB_TYPES = [
    "getPaymentForm",
    "sendPaymentForm",
    "validateOrderInfo",
    "getPaymentReceipt",
    "createInvoiceLink",
    "getPremiumState",
    "getPremiumFeatures",
    "getPremiumGiftPaymentOptions",
    "getPremiumGiveawayPaymentOptions",
    "launchPrepaidPremiumGiveaway",
    "getStarPaymentOptions",
    "getStarGiftPaymentOptions",
    "getStarGiveawayPaymentOptions",
    "getStarTransactions",
    "refundStarPayment",
    "getAvailableGifts",
    "sendGift",
    "sellGift",
    "convertGiftToStars",
    "upgradeGift",
    "transferGift",
    "resellGift",
    "buyResoldGift",
    "getChatBoostStatus",
    "getChatBoostLink",
    "getChatBoostLinkInfo",
    "getUserChatBoosts",
    "boostChat",
    "setChatPaidMessageStarCount",
]


def source_files():
    for base, dirs, files in os.walk(SOURCES):
        dirs[:] = [name for name in dirs if not name.startswith(".")]
        for name in files:
            if name.endswith((".h", ".m", ".mm", ".inc", ".c", ".cpp")):
                yield os.path.join(base, name)


def read_text(path):
    with open(path, "rb") as handle:
        data = handle.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def main():
    errors = []
    patterns = dict((request_type, re.compile(r'@"%s"' % re.escape(request_type)))
                    for request_type in FORBIDDEN_TDLIB_TYPES)
    for path in source_files():
        text = read_text(path)
        for request_type, pattern in patterns.items():
            match = pattern.search(text)
            if match:
                line = text.count("\n", 0, match.start()) + 1
                errors.append("%s:%d: forbidden paid TDLib type %s" %
                              (os.path.relpath(path, ROOT), line, request_type))
    if errors:
        print("Free-feature policy check failed:")
        for error in errors:
            print(" - %s" % error)
        return 1
    print("Free-feature policy check passed; no Telegram commerce request types are present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
