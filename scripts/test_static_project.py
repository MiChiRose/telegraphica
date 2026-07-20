#!/usr/bin/env python
from __future__ import print_function

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
IGNORED_DIRS = set([".git", "build", "build-legacy", "DerivedData", "dist"])


def read_text(path):
    with open(path, "rb") as handle:
        data = handle.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def iter_repo_files():
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not d.startswith("build-tdlib-")]
        for name in files:
            path = os.path.join(base, name)
            yield os.path.relpath(path, ROOT), path


def localization_dictionary(text, name):
    match = re.search(r"NSDictionary \*%s = \[NSDictionary dictionaryWithObjectsAndKeys:(.*?)nil\];" % re.escape(name), text, re.S)
    if not match:
        return {}
    body = match.group(1)
    pairs = re.findall(r'@"((?:[^"\\]|\\.)*)"\s*,\s*@"((?:[^"\\]|\\.)*)"\s*,', body)
    return dict((key, value) for value, key in pairs)


def check_localization(errors):
    rel = os.path.join("Sources", "UI", "TGLocalization.m")
    path = os.path.join(ROOT, rel)
    text = read_text(path)
    dictionaries = {}
    for language in ["ru", "be", "en"]:
        dictionaries[language] = localization_dictionary(text, language)
        if not dictionaries[language]:
            errors.append("%s: missing %s localization dictionary" % (rel, language))
    if len(dictionaries) != 3:
        return

    key_sets = dict((language, set(values.keys())) for language, values in dictionaries.items())
    expected = key_sets["ru"] | key_sets["be"] | key_sets["en"]
    for language, keys in sorted(key_sets.items()):
        missing = sorted(expected - keys)
        if missing:
            errors.append("%s: %s localization is missing keys: %s" % (rel, language, ", ".join(missing[:20])))

    used_keys = set()
    for source_rel, source_path in iter_repo_files():
        if not source_rel.startswith("Sources/"):
            continue
        if not (source_rel.endswith(".m") or source_rel.endswith(".mm") or source_rel.endswith(".inc") or source_rel.endswith(".h")):
            continue
        source_text = read_text(source_path)
        used_keys.update(re.findall(r'TGLoc\(@"([^"]+)"\)', source_text))
    missing_used = sorted(used_keys - expected)
    if missing_used:
        errors.append("TGLoc usages missing from dictionaries: %s" % ", ".join(missing_used[:30]))

    for required in [
        "drawer.all",
        "pinned.title",
        "settings.theme.category.experimental",
        "settings.theme.category.visualWorlds",
        "settings.messages.blocks",
        "message.retrySend",
        "search.chats.title",
    ]:
        if required not in expected:
            errors.append("%s: required UI localization key is missing: %s" % (rel, required))


def check_project_membership(errors):
    project_rel = os.path.join("Telegraphica.xcodeproj", "project.pbxproj")
    project_text = read_text(os.path.join(ROOT, project_rel))
    for rel, path in iter_repo_files():
        if not rel.startswith("Sources/"):
            continue
        if not (rel.endswith(".m") or rel.endswith(".mm")):
            continue
        if rel == os.path.join("Sources", "main.m"):
            name = "main.m"
        else:
            name = os.path.basename(rel)
        if name not in project_text:
            errors.append("%s: source file is not referenced by %s" % (rel, project_rel))


def check_test_structure(errors):
    tests_dir = os.path.join(ROOT, "Tests")
    if not os.path.isdir(tests_dir):
        errors.append("Tests: directory is missing")
    for rel in [
        os.path.join("Tests", "core_logic_probe.m"),
        os.path.join("Tests", "mock_tdlib_event_probe.py"),
        os.path.join("Tests", "media_item_support_probe.m"),
    ]:
        if not os.path.exists(os.path.join(ROOT, rel)):
            errors.append("%s: required test probe is missing" % rel)
    scheme_text = read_text(os.path.join(ROOT, "Telegraphica.xcodeproj", "xcshareddata", "xcschemes", "Telegraphica.xcscheme"))
    if "<Testables>" not in scheme_text:
        errors.append("Telegraphica.xcscheme: TestAction is missing")


def check_no_local_runtime_data(errors):
    forbidden_names = [
        "tdlib-config.plist",
        "TelegraphicaTDLibDefaults.plist",
        "telegram-api.plist",
        "api-credentials.plist",
    ]
    forbidden_extensions = [".session", ".tdlib", ".key"]
    for rel, path in iter_repo_files():
        basename = os.path.basename(rel)
        if basename in forbidden_names:
            errors.append("%s: local credential/runtime data must not be committed" % rel)
        if any(rel.endswith(ext) for ext in forbidden_extensions):
            errors.append("%s: session/key/runtime data must not be committed" % rel)
        if rel == os.path.join("scripts", "check_legacy_compat.py"):
            continue
        if rel.startswith("Tests/") or rel.startswith("scripts/"):
            text = ""
            if rel.endswith((".py", ".m", ".h", ".sh", ".md", ".c")):
                text = read_text(path)
            if re.search(r"api_hash\s*[:=]\s*['\"]?[0-9a-fA-F]{32}", text):
                errors.append("%s: tests/scripts must not contain Telegram API credentials" % rel)


def main():
    errors = []
    if "--self-test-failure" in sys.argv:
        errors.append("intentional static-project failure probe")
    check_localization(errors)
    check_project_membership(errors)
    check_test_structure(errors)
    check_no_local_runtime_data(errors)
    if errors:
        print("Static project tests failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Static project tests passed: localization, project membership, test structure, local-data guard.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
