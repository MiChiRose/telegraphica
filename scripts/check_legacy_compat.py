#!/usr/bin/env python
from __future__ import print_function

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))

SOURCE_EXTENSIONS = (".h", ".m", ".mm", ".c", ".cpp", ".hpp", ".plist", ".pbxproj", ".sh")

FORBIDDEN_TEXT = [
    ("SwiftUI", "SwiftUI is outside the Objective-C/AppKit target."),
    ("@available", "@available is not accepted by the Xcode 6.2 discipline."),
    ("API_AVAILABLE", "API_AVAILABLE is too modern for this project."),
    ("NS_AVAILABLE", "Prefer plain runtime checks and comments over availability macros."),
    ("_Nullable", "Nullability annotations are too modern for the Xcode 6.2 target."),
    ("_Nonnull", "Nullability annotations are too modern for the Xcode 6.2 target."),
    ("NS_ASSUME_NONNULL", "Nullability annotations are too modern for the Xcode 6.2 target."),
    ("NSVisualEffectView", "Vibrancy/visual effect UI is not Mavericks-safe for this project."),
    ("NSSplitViewController", "Use Mavericks-safe manual NSSplitView ownership."),
    ("NSLayoutAnchor", "Use frame/autoresizing or old NSLayoutConstraint APIs."),
    ("activateConstraints:", "Use addConstraints: for Xcode 6.2 compatibility."),
    ("NSStackView", "Use Mavericks-safe manual AppKit layout."),
    ("NSLog(", "Use TGLogger redaction instead of direct NSLog."),
]

GENERIC_RE = re.compile(r"\b(NSArray|NSMutableArray|NSDictionary|NSMutableDictionary|NSSet|NSMutableSet)\s*<")
SECRET_VALUE_RE = re.compile(r"(@?\"?(api_hash|authentication_code|phone_number|database_encryption_key|encryption_key|password|code)\"?\s*[:=]\s*@?\"[^\"]{6,}\")", re.I)


def iter_files():
    ignored_dirs = set([
        ".git",
        "build",
        "build-legacy",
        "build-tdlib-legacy",
        "DerivedData",
    ])
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in ignored_dirs and not d.startswith("build-tdlib-")]
        for name in files:
            path = os.path.join(base, name)
            rel = os.path.relpath(path, ROOT)
            yield rel, path


def read_text(path):
    try:
        with open(path, "rb") as handle:
            data = handle.read()
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def fail(errors, rel, message):
    errors.append("%s: %s" % (rel, message))


def check_sources(errors):
    for rel, path in iter_files():
        if rel.endswith(".swift"):
            fail(errors, rel, "Swift files are not allowed.")
            continue
        if not rel.endswith(SOURCE_EXTENSIONS):
            continue

        text = read_text(path)
        for needle, reason in FORBIDDEN_TEXT:
            if needle == "NSLog(" and rel == os.path.join("Sources", "Services", "TGLogger.m"):
                continue
            if needle in text:
                fail(errors, rel, reason)
        if GENERIC_RE.search(text):
            fail(errors, rel, "Objective-C collection generics are not Xcode 6.2-safe.")
        if rel.startswith("Sources/"):
            for line in text.splitlines():
                if SECRET_VALUE_RE.search(line):
                    fail(errors, rel, "Possible committed Telegram secret or auth value.")
                    break


def check_plist(errors):
    plist = os.path.join(ROOT, "Sources", "Info.plist")
    if not os.path.exists(plist):
        fail(errors, "Sources/Info.plist", "Missing Info.plist.")
        return
    text = read_text(plist)
    if "<key>LSMinimumSystemVersion</key>" not in text or "<string>10.9</string>" not in text:
        fail(errors, "Sources/Info.plist", "LSMinimumSystemVersion must be 10.9.")


def check_project(errors):
    project = os.path.join(ROOT, "Telegraphica.xcodeproj", "project.pbxproj")
    if not os.path.exists(project):
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "Missing Xcode project.")
        return
    text = read_text(project)
    if "MACOSX_DEPLOYMENT_TARGET = 10.9;" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "MACOSX_DEPLOYMENT_TARGET must be 10.9.")
    if "CLANG_ENABLE_OBJC_ARC = NO;" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "ARC must stay disabled until the legacy build lane proves otherwise.")
    if "x86_64" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "x86_64 architecture setting is missing.")


def check_gitignore(errors):
    gitignore = os.path.join(ROOT, ".gitignore")
    if not os.path.exists(gitignore):
        fail(errors, ".gitignore", "Missing .gitignore.")
        return
    text = read_text(gitignore)
    for expected in [".env", "tdlib", "telegram-cache", "*.session", "*.key"]:
        if expected not in text:
            fail(errors, ".gitignore", "Missing ignore entry for %s." % expected)


def main():
    errors = []
    check_sources(errors)
    check_plist(errors)
    check_project(errors)
    check_gitignore(errors)

    if errors:
        print("Legacy compatibility check failed:")
        for error in errors:
            print(" - " + error)
        return 1

    print("Legacy compatibility check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
