#!/usr/bin/env python
# -*- coding: utf-8 -*-
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


def check_media_center_pagination(errors):
    rel = os.path.join("Sources", "UI", "TGStatusWindowController+MediaWindows.inc")
    path = os.path.join(ROOT, rel)
    text = read_text(path)

    page_limit = re.search(r"TGMediaCenterPageLimit\s*=\s*(\d+)", text)
    if not page_limit:
        errors.append("%s: media center page limit constant is missing" % rel)
    elif int(page_limit.group(1)) != 30:
        errors.append("%s: media center page limit should stay at 30 for reliable TDLib paging" % rel)

    required_fragments = [
        "mediaCenterScrollViewBoundsDidChange:",
        "loadMoreMediaCenterIfNeeded",
        "documentHeight - visibleBottom <= 120.0",
        "loadMediaCenterPageAppending:YES sender:nil",
        "self.mediaCenterLoadingMore",
        "self.mediaCenterPaginationAnchorsByFilter",
        "self.mediaCenterExhaustedFilterIdentifiers",
        "fromMessageID:fromMessageID",
        "limit:TGMediaCenterPageLimit",
        "TGMediaCenterOldestMessageIDFromItems(results)",
        "rebuildMediaCenterRowsPreservingScroll:append",
    ]
    for fragment in required_fragments:
        if fragment not in text:
            errors.append("%s: media center pagination contract is missing `%s`" % (rel, fragment))

    if "TGLoc(@\"media.center.titleCard\")" in text or "TGLoc(@\"media.center.hint\")" in text:
        errors.append("%s: removed media center info card should not be rendered again" % rel)

    localization_rel = os.path.join("Sources", "UI", "TGLocalization.m")
    localization_text = read_text(os.path.join(ROOT, localization_rel))
    if "Scroll down to load more." not in localization_text:
        errors.append("%s: English media center status should tell users about scroll pagination" % localization_rel)
    if "Прокрутите вниз, чтобы загрузить ещё." not in localization_text:
        errors.append("%s: Russian media center status should tell users about scroll pagination" % localization_rel)
    if "Пракруціце ўніз, каб загрузіць яшчэ." not in localization_text:
        errors.append("%s: Belarusian media center status should tell users about scroll pagination" % localization_rel)


def check_workshop_download_proxy(errors):
    rel = os.path.join(
        "Sources", "Workshop", "Installation", "TGWorkshopPackageDownloader.m"
    )
    text = read_text(os.path.join(ROOT, rel))
    required_fragments = [
        "TGWorkshopResolvedPackageURL",
        'isEqualToString:@"github.com"',
        "/MiChiRose/telegraphica/releases/download/workshop-modules-v1/",
        "telegraphica-tdlib-config.telegraphica.workers.dev/v1/workshop/package?asset=",
        "[self URLIsAllowed:downloadURL]",
        "requestWithURL:downloadURL",
    ]
    for fragment in required_fragments:
        if fragment not in text:
            errors.append("%s: Workshop compatibility proxy contract is missing `%s`" %
                          (rel, fragment))


def check_workshop_installed_presentation(errors):
    coordinator_rel = os.path.join(
        "Sources", "Workshop", "Host", "TGWorkshopCoordinator.m"
    )
    coordinator_text = read_text(os.path.join(ROOT, coordinator_rel))
    required_fragments = [
        "TGWorkshopInstalledLocalizedNames",
        '[identifier hasSuffix:@".fifteen"]',
        'russian = @"Пятнашки"',
        '[identifier componentsSeparatedByString:@"."]',
    ]
    for fragment in required_fragments:
        if fragment not in coordinator_text:
            errors.append("%s: installed-module presentation is missing `%s`" %
                          (coordinator_rel, fragment))
    if "[identifier lastPathComponent]" in coordinator_text:
        errors.append("%s: dotted module identifiers must not be shown via lastPathComponent" %
                      coordinator_rel)

    notice_rel = os.path.join(
        "Sources", "Workshop", "UI", "TGWorkshopHeaderNoticeView.m"
    )
    notice_text = read_text(os.path.join(ROOT, notice_rel))
    for fragment in ["showMessage:", "hideAnimated", "setAlphaValue:"]:
        if fragment not in notice_text:
            errors.append("%s: refresh notice animation is missing `%s`" %
                          (notice_rel, fragment))


def check_unified_legacy_contract(errors):
    info_rel = os.path.join("Sources", "Info.plist")
    info_text = read_text(os.path.join(ROOT, info_rel))
    if "<key>LSMinimumSystemVersion</key>\n\t<string>10.8</string>" not in info_text:
        errors.append("%s: unified app must keep LSMinimumSystemVersion at 10.8" % info_rel)
    if "OS X 10.8–macOS 10.13" not in info_text:
        errors.append("%s: unified compatibility summary is missing" % info_rel)

    compatibility_rel = os.path.join("Sources", "Services", "TGSystemCompatibility.h")
    compatibility_text = read_text(os.path.join(ROOT, compatibility_rel))
    for fragment in ["NSAppKitVersionNumber < 1265.0", "TGSystemIsMountainLion"]:
        if fragment not in compatibility_text:
            errors.append("%s: runtime Mountain Lion detection is missing `%s`" %
                          (compatibility_rel, fragment))
    if "LSMinimumSystemVersion" in compatibility_text:
        errors.append("%s: runtime detection must not inspect the deployment-target plist key" %
                      compatibility_rel)

    base64_rel = os.path.join("Sources", "Services", "TGBase64Compatibility.h")
    base64_text = read_text(os.path.join(ROOT, base64_rel))
    for fragment in ["TGBase64EncodedString", "TGDataFromBase64String",
                     "base64Encoding", "initWithBase64Encoding:"]:
        if fragment not in base64_text:
            errors.append("%s: shared Mountain Lion Base64 helper is missing `%s`" %
                          (base64_rel, fragment))

    for rel in [
        os.path.join("Sources", "Core", "TGTDLibClient.m"),
        os.path.join("Sources", "UI", "TGStatusWindowController.m"),
    ]:
        text = read_text(os.path.join(ROOT, rel))
        if "TGSystemIsMountainLion()" not in text:
            errors.append("%s: shared runtime compatibility helper is not used" % rel)
    tdlib_text = read_text(os.path.join(ROOT, "Sources", "Core", "TGTDLibClient.m"))
    if "TGTDLibPruneMountainLionBackups(backupRoot, 3)" not in tdlib_text:
        errors.append("Sources/Core/TGTDLibClient.m: Mountain Lion cache backups must stay bounded")

    startup_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageDataFlow.inc")
    startup_text = read_text(os.path.join(ROOT, startup_rel))
    for fragment in [
        "error:&parametersError",
        "parametersErrorCode >= 12",
        "parametersErrorCode <= 14",
    ]:
        if fragment not in startup_text:
            errors.append("%s: TDLib startup must distinguish missing configuration from transient failures `%s`" %
                          (startup_rel, fragment))

    build_rel = "build_legacy.sh"
    build_text = read_text(os.path.join(ROOT, build_rel))
    for fragment in [
        "MACOSX_DEPLOYMENT_TARGET:-10.8",
        "check_release_bundle_legacy.sh",
        "Xcode 5.1.1.app",
        "TELEGRAPHICA_BUNDLED_TDLIB_CREDENTIALS_SOURCE_PATH",
        "Preserved the existing generated Telegram connection provider.",
    ]:
        if fragment not in build_text:
            errors.append("%s: unified legacy build contract is missing `%s`" %
                          (build_rel, fragment))

    package_rel = os.path.join("scripts", "package_legacy_release_artifacts.sh")
    package_text = read_text(os.path.join(ROOT, package_rel))
    if "macos10.8-10.13" not in package_text:
        errors.append("%s: unified release artifact compatibility tag is missing" % package_rel)

    for rel in [
        os.path.join("Sources", "UI", "TGUpdateSupport.h"),
        os.path.join("Sources", "UI", "TGUpdateSupport.m"),
        os.path.join("Sources", "UI", "TGStatusWindowController.m"),
        os.path.join("Sources", "UI", "TGStatusWindowController+Notifications.inc"),
    ]:
        if "TGCurrentApplicationVersionIsMountainLionBuild" in read_text(os.path.join(ROOT, rel)):
            errors.append("%s: unified updater must not disable itself through the old -ml release suffix" % rel)

    if os.path.exists(os.path.join(ROOT, "build_mountain_lion.sh")):
        errors.append("build_mountain_lion.sh: separate Mountain Lion build wrapper must not return")


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
    check_media_center_pagination(errors)
    check_workshop_download_proxy(errors)
    check_workshop_installed_presentation(errors)
    check_unified_legacy_contract(errors)
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
