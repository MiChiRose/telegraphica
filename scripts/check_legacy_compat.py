#!/usr/bin/env python
from __future__ import print_function

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
DEPLOYMENT_TARGET = os.environ.get("TELEGRAPHICA_DEPLOYMENT_TARGET") or os.environ.get("MACOSX_DEPLOYMENT_TARGET") or "10.8"

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
    ("base64EncodedStringWithOptions:", "Use NSData base64Encoding for the OS X 10.8 Mountain Lion lane."),
    ("base64EncodedDataWithOptions:", "Use NSData base64Encoding for the OS X 10.8 Mountain Lion lane."),
    ("initWithBase64EncodedString:", "Use NSData initWithBase64Encoding: for the OS X 10.8 Mountain Lion lane."),
    ("initWithBase64EncodedData:", "Use NSData initWithBase64Encoding: for the OS X 10.8 Mountain Lion lane."),
    ("dataWithBase64EncodedString:", "Use NSData initWithBase64Encoding: for the OS X 10.8 Mountain Lion lane."),
    ("NSDataBase64EncodingOptions", "Use the pre-10.9 NSData base64Encoding APIs for the Mountain Lion lane."),
    ("NSDataBase64DecodingOptions", "Use the pre-10.9 NSData initWithBase64Encoding: APIs for the Mountain Lion lane."),
    ("colorWithWhite:", "Use colorWithCalibratedWhite:alpha: or colorWithDeviceWhite:alpha: for OS X 10.8."),
    ("colorWithRed:", "Use colorWithCalibratedRed:green:blue:alpha: or colorWithDeviceRed:green:blue:alpha: for OS X 10.8."),
    ("colorWithHue:", "Use colorWithCalibratedHue:saturation:brightness:alpha: or colorWithDeviceHue:saturation:brightness:alpha: for OS X 10.8."),
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
    expected = "<string>%s</string>" % DEPLOYMENT_TARGET
    if "<key>LSMinimumSystemVersion</key>" not in text or expected not in text:
        fail(errors, "Sources/Info.plist", "LSMinimumSystemVersion must be %s." % DEPLOYMENT_TARGET)


def check_project(errors):
    project = os.path.join(ROOT, "Telegraphica.xcodeproj", "project.pbxproj")
    if not os.path.exists(project):
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "Missing Xcode project.")
        return
    text = read_text(project)
    expected = "MACOSX_DEPLOYMENT_TARGET = %s;" % DEPLOYMENT_TARGET
    if expected not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "MACOSX_DEPLOYMENT_TARGET must be %s." % DEPLOYMENT_TARGET)
    if "CLANG_ENABLE_OBJC_ARC = NO;" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "ARC must stay disabled until the legacy build lane proves otherwise.")
    if "x86_64" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "x86_64 architecture setting is missing.")
    if "TGLocalDataReset.m" not in text:
        fail(errors, "Telegraphica.xcodeproj/project.pbxproj", "TGLocalDataReset.m must be part of the Xcode project.")


def check_gitignore(errors):
    gitignore = os.path.join(ROOT, ".gitignore")
    if not os.path.exists(gitignore):
        fail(errors, ".gitignore", "Missing .gitignore.")
        return
    text = read_text(gitignore)
    for expected in [".env", "tdlib", "telegram-cache", "*.session", "*.key"]:
        if expected not in text:
            fail(errors, ".gitignore", "Missing ignore entry for %s." % expected)


def check_local_data_reset(errors):
    rel = os.path.join("Sources", "Services", "TGLocalDataReset.m")
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        fail(errors, rel, "Missing local data reset service.")
        return
    text = read_text(path)
    required = [
        "Application Support",
        "Library/Caches",
        "TGMediaImageLoaderClearCache",
        "clearDiagnosticFile",
        "deleteForAccount",
        "shutdownWithTimeout",
        "Telegram cloud data remains online",
    ]
    for needle in required:
        if needle not in text:
            fail(errors, rel, "Local data reset is missing expected safety step: %s." % needle)
    forbidden = [
        "NSDownloadsDirectory",
        "NSDocumentDirectory",
        "NSDesktopDirectory",
        "removeItemAtPath:NSHomeDirectory",
        "stringByAppendingPathComponent:@\"Downloads\"",
        "stringByAppendingPathComponent:@\"Desktop\"",
    ]
    for needle in forbidden:
        if needle in text:
            fail(errors, rel, "Local data reset must not target user-owned locations: %s." % needle)


def check_diagnostic_redaction(errors):
    logger_rel = os.path.join("Sources", "Services", "TGLogger.m")
    logger_path = os.path.join(ROOT, logger_rel)
    auth_rel = os.path.join("Sources", "UI", "TGStatusWindowController+AuthComposerState.inc")
    auth_path = os.path.join(ROOT, auth_rel)
    if not os.path.exists(logger_path) or not os.path.exists(auth_path):
        return
    logger_text = read_text(logger_path)
    auth_text = read_text(auth_path)
    for needle in ["api_hash", "/Users/", "chat id", "message id", "file id"]:
        if needle not in logger_text:
            fail(errors, logger_rel, "Diagnostic redaction should cover %s." % needle)
    if "redactedDiagnosticMessage" not in auth_text:
        fail(errors, auth_rel, "appendDetail must pass Diagnostic Logs through TGLogger redaction.")

    def redact_sample(message):
        lowered = message.lower()
        sensitive = [
            "api_hash",
            "authentication_code",
            "authentication code",
            "auth code",
            "phone_number",
            "phone number",
            "database_encryption_key",
            "encryption_key",
            "password",
            "\"code\"",
            "login code",
            "api id",
            "api_id",
        ]
        for marker in sensitive:
            if marker in lowered:
                return "<redacted sensitive log line>"
        redacted = message
        redacted = re.sub(r"(Downloaded (cached fallback )?to\s+).+", r"\1<redacted-path>", redacted, flags=re.I)
        redacted = re.sub(r"(Submitting [^\n:]+ to TDLib:\s+).+", r"\1<redacted-file>", redacted, flags=re.I)
        redacted = re.sub(r"\b((chat|folder)\s+(title|name)|title|preview|caption|message\s+(text|preview|body)|text|file(name)?|path)\s*[:=]\s*(\"[^\"]*\"|'[^']*'|[^,;\n]+)", r"\1=<redacted>", redacted, flags=re.I)
        redacted = re.sub(r"(chat id|chat_id|message id|message_id|file id|file_id)[:= ]+[^\s,;]+", r"\1=<redacted-id>", redacted, flags=re.I)
        redacted = re.sub(r"([?&](token|hash|code|key|password)=)[^\s&]+", r"\1<redacted>", redacted, flags=re.I)
        redacted = re.sub(r"\+?[0-9][0-9 ()-]{7,}[0-9]", "<redacted-number>", redacted)
        redacted = re.sub(r"\b[A-Fa-f0-9]{32,}\b", "<redacted-token>", redacted)
        redacted = re.sub(r"(/Users/[^\n\r]+)", "<redacted-path>", redacted)
        redacted = re.sub(r"\b[0-9]{5,}\b", "<redacted-number>", redacted)
        return redacted

    samples = [
        "Downloaded to /Users/Test User/Desktop/private photo.png",
        "Submitting document to TDLib: salary-contract.rtf",
        "chat_id=123456789 message_id=9988776655 file_id=8877665544",
        "chat title=Family Folder folder name=Secret Work",
        "preview=hello private message text=never log caption=secret",
        "phone_number=+375 29 123 45 67 api_hash=0123456789abcdef0123456789abcdef",
    ]
    forbidden_fragments = [
        "/Users/Test User",
        "private photo.png",
        "salary-contract.rtf",
        "123456789",
        "9988776655",
        "8877665544",
        "Family",
        "Secret Work",
        "hello private",
        "never log",
        "+375",
        "0123456789abcdef",
    ]
    for sample in samples:
        redacted = redact_sample(sample)
        for fragment in forbidden_fragments:
            if fragment in redacted:
                fail(errors, logger_rel, "Diagnostic redaction sample leaked %s from %r." % (fragment, sample))
                break


def main():
    errors = []
    check_sources(errors)
    check_plist(errors)
    check_project(errors)
    check_gitignore(errors)
    check_local_data_reset(errors)
    check_diagnostic_redaction(errors)

    if errors:
        print("Legacy compatibility check failed:")
        for error in errors:
            print(" - " + error)
        return 1

    print("Legacy compatibility check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
