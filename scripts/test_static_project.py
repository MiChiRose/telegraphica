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
    if u"Прокрутите вниз, чтобы загрузить ещё." not in localization_text:
        errors.append("%s: Russian media center status should tell users about scroll pagination" % localization_rel)
    if u"Пракруціце ўніз, каб загрузіць яшчэ." not in localization_text:
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
        u'russian = @"Пятнашки"',
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
    if u"OS X 10.8–macOS 10.13" not in info_text:
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
    for fragment in [
        'TELEGRAPHICA_TDJSON_MOUNTAIN_LION_PATH',
        'mountainLion ? @"libtdjson-mountain-lion.dylib" : @"libtdjson.dylib"',
        "if (!mountainLion)",
    ]:
        if fragment not in tdlib_text:
            errors.append("Sources/Core/TGTDLibClient.m: dual TDLib runtime selection is missing `%s`" %
                          fragment)
    if "TGTDLibStartupRecovery" in tdlib_text:
        errors.append("Sources/Core/TGTDLibClient.m: TDLib cache migration recovery must not return")

    startup_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageDataFlow.inc")
    startup_text = read_text(os.path.join(ROOT, startup_rel))
    for fragment in [
        "hasPotentialTDLibConfigurationSource",
        "!parametersConfigurationAvailable",
        "authorization state will be checked again",
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
        "TELEGRAPHICA_TDJSON_MOUNTAIN_LION_PATH",
        "libtdjson-mountain-lion.dylib",
        "Preserved the existing generated Telegram connection provider.",
        "Found the existing Mavericks-and-newer TDLib JSON library.",
        "Found the existing Mountain Lion TDLib JSON library.",
    ]:
        if fragment not in build_text:
            errors.append("%s: unified legacy build contract is missing `%s`" %
                          (build_rel, fragment))

    package_rel = os.path.join("scripts", "package_legacy_release_artifacts.sh")
    package_text = read_text(os.path.join(ROOT, package_rel))
    if "macos10.8-10.13" not in package_text:
        errors.append("%s: unified release artifact compatibility tag is missing" % package_rel)
    for fragment in ["--mountain-lion-tdjson", "libtdjson-mountain-lion.dylib"]:
        if fragment not in package_text:
            errors.append("%s: dual TDLib release contract is missing `%s`" %
                          (package_rel, fragment))

    recovery_rel = os.path.join("Sources", "Services", "TGTDLibStartupRecovery.m")
    if os.path.exists(os.path.join(ROOT, recovery_rel)):
        errors.append("%s: destructive TDLib cache recovery helper must not return" % recovery_rel)

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


def check_conversation_creation_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in [
        'createNewBasicGroupChat',
        'createNewSecretChat',
        'createNewSupergroupChat',
        'createdBasicGroupChat',
        'message_auto_delete_time',
        'telegraphica-create-basic-group-legacy',
        'telegraphica-create-supergroup-legacy',
        'isTDLibSchemaCompatibilityError',
    ]:
        if fragment not in client_text:
            errors.append("%s: conversation creation compatibility is missing `%s`" %
                          (client_rel, fragment))

    prompt_rel = os.path.join("Sources", "UI", "TGConversationCreationPrompt.m")
    prompt_text = read_text(os.path.join(ROOT, prompt_rel))
    for fragment in ["runGroupPromptWithMemberCount:", "runChannelPromptWithTitle:",
                     "[safeTitle length] > 128", "[safeDescription length] > 255"]:
        if fragment not in prompt_text:
            errors.append("%s: focused creation prompt is missing `%s`" %
                          (prompt_rel, fragment))

    lifecycle_rel = os.path.join("Sources", "UI", "TGChatLifecycleWindowController.m")
    lifecycle_text = read_text(os.path.join(ROOT, lifecycle_rel))
    for fragment in ["setAllowsMultipleSelection:YES", "createGroup:",
                     "createSecretChat:", "createChannel:"]:
        if fragment not in lifecycle_text:
            errors.append("%s: conversation creation UI is missing `%s`" %
                          (lifecycle_rel, fragment))


def check_composer_formatting_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in ["parseTextEntities", "textParseModeMarkdown",
                     "telegraphica-parse-composer-formatting", u'@"\\u2063"']:
        if fragment not in client_text:
            errors.append("%s: rich composer parsing is missing `%s`" %
                          (client_rel, fragment))

    composer_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ComposerMedia.inc")
    composer_text = read_text(os.path.join(ROOT, composer_rel))
    for fragment in ["applyComposerFormatting:", 'TGLoc(@"composer.format.spoiler")',
                     'TGLoc(@"composer.format.code")']:
        if fragment not in composer_text:
            errors.append("%s: composer formatting UI is missing `%s`" %
                          (composer_rel, fragment))

    draft_rel = os.path.join("Sources", "UI", "TGStatusWindowController+AuthComposerState.inc")
    if u'[text hasPrefix:@"\\u2063"]' not in read_text(os.path.join(ROOT, draft_rel)):
        errors.append("%s: formatting control markers must not sync into Telegram drafts" % draft_rel)


def check_additional_message_types_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in [
        "sendContactMessageToChatID:",
        '"inputMessageContact"',
        "sendLocationMessageToChatID:",
        '"inputMessageLocation"',
        '"live_period"',
        "sendAnimationMessageToChatID:",
        '"inputMessageAnimation"',
        '"inputAnimation"',
        "TGTDLibSendErrorLooksLikeSchemaMismatch(sendError)",
    ]:
        if fragment not in client_text:
            errors.append("%s: additional message type compatibility is missing `%s`" %
                          (client_rel, fragment))

    descriptor_rel = os.path.join("Sources", "Media", "TGAttachmentDescriptor.m")
    descriptor_text = read_text(os.path.join(ROOT, descriptor_rel))
    for fragment in ['[descriptor.extension isEqualToString:@"gif"]',
                     "TGAttachmentKindAnimation", 'descriptor.typeLabel = @"GIF"']:
        if fragment not in descriptor_text:
            errors.append("%s: GIF routing contract is missing `%s`" %
                          (descriptor_rel, fragment))

    dialogs_rel = os.path.join("Sources", "UI", "TGMessageActionDialogs.m")
    dialogs_text = read_text(os.path.join(ROOT, dialogs_rel))
    for fragment in ["contactToShare", "locationToShare",
                     "latitude < -90.0", "longitude > 180.0"]:
        if fragment not in dialogs_text:
            errors.append("%s: share dialog validation is missing `%s`" %
                          (dialogs_rel, fragment))

    composer_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ComposerMedia.inc")
    composer_text = read_text(os.path.join(ROOT, composer_rel))
    for fragment in ["shareContactFromComposerMenu:", "shareLocationFromComposerMenu:",
                     "sendAnimationMessageToChatID:"]:
        if fragment not in composer_text:
            errors.append("%s: composer message-type routing is missing `%s`" %
                          (composer_rel, fragment))


def check_media_file_management_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in [
        "cancelDownloadForFileID:",
        '"cancelDownloadFile"',
        '"only_if_pending"',
        "deleteCachedFileForFileID:",
        '"deleteFile"',
        "downloadedFileInfoForFileID:fileID timeout:timeout error:error",
    ]:
        if fragment not in client_text:
            errors.append("%s: TDLib media file management is missing `%s`" %
                          (client_rel, fragment))

    actions_rel = os.path.join("Sources", "Media", "TGMediaFileActions.m")
    actions_text = read_text(os.path.join(ROOT, actions_rel))
    for fragment in [
        "confirmDeleteLocalCopyWithFileName:",
        "saveCopyOfFileAtPath:",
        "toDirectory:",
        "NSSavePanel",
        "selectFile:path",
        "copyItemAtPath:sourcePath",
        "createDirectoryAtPath:directoryPath",
    ]:
        if fragment not in actions_text:
            errors.append("%s: focused local file action is missing `%s`" %
                          (actions_rel, fragment))

    media_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MediaWindows.inc")
    media_text = read_text(os.path.join(ROOT, media_rel))
    for fragment in [
        "mediaCenterDownloadingFileIDs",
        "cancelMediaCenterDownload:",
        "saveMediaCenterItemAs:",
        "revealMediaCenterItem:",
        "deleteCachedFileForFileID:",
        "TGConfiguredDownloadFolderPath()",
        "mediaCenterSavedPathsByFileID",
        'TGLoc(@"media.center.downloadedTo")',
    ]:
        if fragment not in media_text:
            errors.append("%s: Media Center file action routing is missing `%s`" %
                          (media_rel, fragment))
    if "removeItemAtPath:path error:&error" in media_text:
        errors.append("%s: Media Center must delete cached files through TDLib, not unlink cache paths directly" %
                      media_rel)


def check_primary_navigation_contract(errors):
    controller_rel = os.path.join("Sources", "UI", "TGStatusWindowController.m")
    controller_text = read_text(os.path.join(ROOT, controller_rel))
    for fragment in [
        'arrayWithObjects:@"Contacts", @"Calls", @"Chats", @"Settings", nil',
        "NSInteger navigationTags[] = {0, 1, 2, 3}",
        "TGSectionContacts",
        "TGSectionCalls",
        "contactsViewController",
        "callsPlaceholderView",
        "settingsProfileButton",
    ]:
        if fragment not in controller_text:
            errors.append("%s: four-section navigation contract is missing `%s`" %
                          (controller_rel, fragment))

    contacts_rel = os.path.join("Sources", "UI", "TGContactsViewController.m")
    contacts_text = read_text(os.path.join(ROOT, contacts_rel))
    for fragment in [
        "contactSummariesWithTimeout:",
        "privateChatIDForUserID:",
        "userProfileSummaryForUserID:",
        "applySearchFilter",
        "loadSelectedContactProfile",
        "TGContactProfileView",
        "contactsViewControllerDidRequestNewConversation:",
    ]:
        if fragment not in contacts_text:
            errors.append("%s: contacts section is missing `%s`" %
                          (contacts_rel, fragment))

    button_cells_rel = os.path.join("Sources", "UI", "TGStatusButtonCells.m")
    button_cells_text = read_text(os.path.join(ROOT, button_cells_rel))
    for asset_name in ["call-receive", "settings"]:
        asset_rel = os.path.join("Sources", "Resources", "Icons", asset_name + ".png")
        if not os.path.isfile(os.path.join(ROOT, asset_rel)):
            errors.append("%s: approved navigation icon asset is missing" % asset_rel)
        expected_draw = 'TGDrawTemplateIconAsset(@"%s"' % asset_name
        if expected_draw not in button_cells_text:
            errors.append("%s: navigation must render approved asset `%s`" %
                          (button_cells_rel, asset_name))

    navigation_draw_start = button_cells_text.find("static void TGDrawNavigationIcon")
    navigation_draw_end = button_cells_text.find("@implementation TGNavigationButtonCell")
    navigation_draw_text = button_cells_text[navigation_draw_start:navigation_draw_end]
    if "NSBezierPath *receiver" in navigation_draw_text:
        errors.append("%s: call navigation icon must not be hand-drawn" % button_cells_rel)
    if "CGFloat iconSize = 18.0;" not in button_cells_text:
        errors.append("%s: primary navigation icons must keep the compact 18-point size" %
                      button_cells_rel)
    if "TGPrimaryTextButtonCell *openCell" not in contacts_text:
        errors.append("%s: open-chat action must use the themed primary text-button cell" %
                      contacts_rel)
    if 'TGDrawTemplateIconAsset(@"route-arrow"' not in button_cells_text:
        errors.append("%s: drawer back state must use the approved route-arrow asset" %
                      button_cells_rel)
    if "profileBackButton" in controller_text:
        errors.append("%s: profile must reuse the drawer button back state, not add a separate text button" %
                      controller_rel)

    section_layout_rel = os.path.join("Sources", "UI", "TGStatusWindowController+SectionLayout.inc")
    section_layout_text = read_text(os.path.join(ROOT, section_layout_rel))
    for fragment in [
        "drawerFolderScrollView",
        "drawerFolderContentView",
        "drawerFolderButtonHeight = 46.0",
        "drawerFolderRequiredHeight",
        "drawerTopInset = 8.0",
    ]:
        if fragment not in controller_text and fragment not in section_layout_text:
            errors.append("%s: scrollable top-aligned drawer is missing `%s`" %
                          (section_layout_rel, fragment))
    if "drawerFolderButtonHeight = floor" in section_layout_text:
        errors.append("%s: drawer folder rows must scroll instead of shrinking with the window" %
                      section_layout_rel)
    if "NSWidth([self.drawerFolderScrollView contentSize])" in section_layout_text:
        errors.append("%s: NSWidth requires NSRect; use the scroll contentView bounds on legacy AppKit" %
                      section_layout_rel)
    for fragment in [
        "minimumChatSidebarWidth",
        "standardChatSidebarWidth",
        "maximumChatSidebarWidthForWindowWidth",
        "sidebarResizeHandleDidRequestToggle",
        "compactChatSidebar",
        "return (width < 248.0)",
        "[self.drawerButton setFrame:NSMakeRect(mainX + 12.0",
        "CGFloat initialWidth = [handle initialDragWidth]",
        "clampedWidth = (naturalWidth < standardWidth) ? minimumWidth : naturalWidth",
    ]:
        if fragment not in section_layout_text:
            errors.append("%s: flexible chat sidebar is missing `%s`" %
                          (section_layout_rel, fragment))
    components_header_rel = os.path.join("Sources", "UI", "TGStatusViewComponents.h")
    components_header_text = read_text(os.path.join(ROOT, components_header_rel))
    if "TGSidebarResizeHandleView" not in components_header_text:
        errors.append("%s: chat sidebar resize handle is missing" % components_header_rel)
    if "- (CGFloat)initialDragWidth;" not in components_header_text:
        errors.append("%s: sidebar snap resizing needs the drag's initial width" % components_header_rel)
    components_impl_rel = os.path.join("Sources", "UI", "TGStatusViewComponents.m")
    components_impl_text = read_text(os.path.join(ROOT, components_impl_rel))
    for fragment in [
        "NSTrackingMouseEnteredAndExited",
        "[[NSCursor resizeLeftRightCursor] set]",
        "- (void)mouseUp:(NSEvent *)event",
    ]:
        if fragment not in components_impl_text:
            errors.append("%s: resize handle cursor tracking is missing `%s`" %
                          (components_impl_rel, fragment))

    chat_search_panel_rel = os.path.join("Sources", "UI", "TGChatSearchPanelView.inc")
    chat_search_panel_text = read_text(os.path.join(ROOT, chat_search_panel_rel))
    if '[_searchField setAction:@selector(commitSearch:)]' in chat_search_panel_text:
        errors.append("%s: typing in NSSearchField must not auto-commit the first result" %
                      chat_search_panel_rel)
    for fragment in [
        "[_tableView setAction:@selector(commitSearch:)]",
        "commandSelector == @selector(moveDown:)",
        "commandSelector == @selector(moveUp:)",
        "[_tableView deselectAll:self]",
        "[TGClassicSelectedRowColor() set]",
    ]:
        if fragment not in chat_search_panel_text:
            errors.append("%s: explicit chat-search selection is missing `%s`" %
                          (chat_search_panel_rel, fragment))
    chat_search_window_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ChatSearchWindow.inc")
    chat_search_window_text = read_text(os.path.join(ROOT, chat_search_window_rel))
    if "result = [self.chatSearchWindowResults objectAtIndex:0]" in chat_search_window_text:
        errors.append("%s: chat search must not navigate to the first result without a selection" %
                      chat_search_window_rel)

    lifecycle_rel = os.path.join("Sources", "UI", "TGChatLifecycleWindowController.m")
    lifecycle_text = read_text(os.path.join(ROOT, lifecycle_rel))
    for fragment in [
        "TGChatLifecycleContactCell",
        "TGGroupedCardView *contactsCard",
        "TGPrimaryTextButtonCell",
        "TGSecondaryTextButtonCell",
    ]:
        if fragment not in lifecycle_text:
            errors.append("%s: polished new-chat window is missing `%s`" %
                          (lifecycle_rel, fragment))

    chat_cells_rel = os.path.join("Sources", "UI", "TGStatusViewCells.m")
    chat_cells_text = read_text(os.path.join(ROOT, chat_cells_rel))
    if 'TGDrawTemplateIconAsset(@"sound-off"' not in chat_cells_text:
        errors.append("%s: muted chats need the approved sound-off icon" % chat_cells_rel)
    if 'TGLoc(@"chat.notifications.mutedBadge")' in chat_cells_text:
        errors.append("%s: muted chats must not replace the sound-off icon with text" % chat_cells_rel)
    if "BOOL compact = (NSWidth(cellFrame) < 223.0)" not in chat_cells_text:
        errors.append("%s: chat rows must switch to compact rendering with the sidebar shell" % chat_cells_rel)
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in [
        "getScopeNotificationSettings",
        "use_default_mute_for",
        "updateScopeNotificationSettings",
        "last_read_inbox_message_id",
        "aroundMessageID:",
        "offset:-safeNewerCount",
    ]:
        if fragment not in client_text:
            errors.append("%s: server notification scope sync is missing `%s`" %
                          (client_rel, fragment))
    message_flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageDataFlow.inc")
    message_flow_text = read_text(os.path.join(ROOT, message_flow_rel))
    for fragment in [
        "scrollMessagesToInitialUnreadIfAvailable",
        "visibleUnreadMessageItemsAwaitingReceipt",
        "markVisibleMessageItemsReadForChatID",
        "!shouldLoadUnreadBoundary",
    ]:
        if fragment not in message_flow_text:
            errors.append("%s: viewport-based unread handling is missing `%s`" %
                          (message_flow_rel, fragment))
    if "scheduleMessageItemsReadForChatID" in message_flow_text:
        errors.append("%s: loading a chat must not mark the whole fetched history as read" %
                      message_flow_rel)

    message_hit_testing_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMediaHitTesting.inc")
    message_hit_testing_text = read_text(os.path.join(ROOT, message_hit_testing_rel))
    message_menus_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    message_menus_text = read_text(os.path.join(ROOT, message_menus_rel))
    table_flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+TableForumFlow.inc")
    table_flow_text = read_text(os.path.join(ROOT, table_flow_rel))
    for fragment in [
        "TGMessageItemIsNonVisualDocument",
        "openDocumentAttachmentForMessageItem",
    ]:
        if fragment not in message_hit_testing_text:
            errors.append("%s: document bubble interaction is missing `%s`" %
                          (message_hit_testing_rel, fragment))
    for fragment in [
        "openMessageDocumentFromMenu",
        "saveMessageDocumentAsFromMenu",
        "revealMessageDocumentFromMenu",
    ]:
        if fragment not in message_menus_text:
            errors.append("%s: direct document action is missing `%s`" %
                          (message_menus_rel, fragment))
    if "TGMessageItemIsNonVisualDocument" not in table_flow_text:
        errors.append("%s: document bubbles must expose an action tooltip" % table_flow_rel)

    contacts_rel = os.path.join("Sources", "UI", "TGContactsViewController.m")
    contacts_text = read_text(os.path.join(ROOT, contacts_rel))
    client_header_rel = os.path.join("Sources", "Core", "TGTDLibClient.h")
    client_header_text = read_text(os.path.join(ROOT, client_header_rel))
    dialogs_rel = os.path.join("Sources", "UI", "TGContactManagementDialogs.m")
    dialogs_text = read_text(os.path.join(ROOT, dialogs_rel))
    for fragment in [
        "addContactWithPhoneNumber",
        "removeContactWithUserID",
    ]:
        if fragment not in client_header_text:
            errors.append("%s: contact management API is missing `%s`" %
                          (client_header_rel, fragment))
    for fragment in [
        "showCreateMenu",
        "showSelectedContactActions",
        "sendSelectedContact",
        "removeSelectedContact",
        "inviteSelectedContact",
    ]:
        if fragment not in contacts_text:
            errors.append("%s: contact management action is missing `%s`" %
                          (contacts_rel, fragment))
    if "contactToAdd" not in dialogs_text or "confirmRemovalOfContactNamed" not in dialogs_text:
        errors.append("%s: add/remove confirmation dialogs are incomplete" % dialogs_rel)

    profile_editor_rel = os.path.join("Sources", "UI", "TGProfileEditWindowController.m")
    profile_editor_text = read_text(os.path.join(ROOT, profile_editor_rel))
    utility_windows_rel = os.path.join("Sources", "UI", "TGStatusWindowController+UtilityWindows.inc")
    utility_windows_text = read_text(os.path.join(ROOT, utility_windows_rel))
    message_data_flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageDataFlow.inc")
    message_data_flow_text = read_text(os.path.join(ROOT, message_data_flow_rel))
    for fragment in [
        "setName",
        "setUsername",
        "setBio",
        "updateCurrentUserFirstName",
    ]:
        if fragment not in client_text:
            errors.append("%s: profile editing TDLib request is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "TGProfileEditWindowController",
        "TGPrimaryTextButtonCell",
        "profile.edit.firstNameRequired",
    ]:
        if fragment not in profile_editor_text:
            errors.append("%s: profile editor is missing `%s`" %
                          (profile_editor_rel, fragment))
    for fragment in [
        "showProfileEditWindow:",
        "didRequestSaveFirstName:",
        "reloadProfileSummaryIfReady",
        "[NSApp activateIgnoringOtherApps:YES]",
        'log:@"Profile editor presented."',
    ]:
        if fragment not in utility_windows_text:
            errors.append("%s: profile editor wiring is missing `%s`" %
                          (utility_windows_rel, fragment))
    authorization_probe_index = message_data_flow_text.find(
        "authorizationState = [client authorizationStateSummaryWithTimeout:")
    network_diagnostics_index = message_data_flow_text.find(
        "networkDiagnosticsSummary = [client networkDiagnosticsSummaryWithTimeout:")
    if authorization_probe_index < 0 or network_diagnostics_index < 0:
        errors.append("%s: TDLib bootstrap diagnostics contract is incomplete" %
                      message_data_flow_rel)
    elif network_diagnostics_index < authorization_probe_index:
        errors.append("%s: network diagnostics must not block the initial authorization-state probe" %
                      message_data_flow_rel)
    for fragment in [
        "profileGroupedX + profileGroupedWidth - 22.0 - profileEditWidth",
        "profileGroupedWidth - 44.0",
        "[self showView:self.profileEditButton visible:showProfile];",
    ]:
        if fragment not in section_layout_text:
            errors.append("%s: safe profile action layout is missing `%s`" %
                          (section_layout_rel, fragment))
    for fragment in [
        "supportsMessageViewers",
        '[messageViewersChatType isEqualToString:@"Group"]',
        '[messageViewersChatType isEqualToString:@"Supergroup"]',
        "if ([item outgoing] && supportsMessageViewers)",
    ]:
        if fragment not in message_menus_text:
            errors.append("%s: message viewers visibility contract is missing `%s`" %
                          (message_menus_rel, fragment))

    calls_header_rel = os.path.join("Sources", "UI", "TGCallsPlaceholderView.h")
    calls_implementation_rel = os.path.join("Sources", "UI", "TGCallsPlaceholderView.m")
    calls_header_text = read_text(os.path.join(ROOT, calls_header_rel))
    calls_implementation_text = read_text(os.path.join(ROOT, calls_implementation_rel))
    if "TGCallsPlaceholderView : TGPanelView" not in calls_header_text:
        errors.append("%s: calls must use the shared panel/header shell" % calls_header_rel)
    if "NSHeight(bounds) - 68.0" not in calls_implementation_text:
        errors.append("%s: calls card must fill the panel body" % calls_implementation_rel)


def check_retro_console_contract(errors):
    module_rel = os.path.join("WorkshopModules", "RetroConsole")
    controller_rel = os.path.join(module_rel, "TGRetroConsoleViewController.m")
    display_rel = os.path.join(module_rel, "TGRetroDisplayView.m")
    core_rel = os.path.join(module_rel, "TGRetroLibretroCore.m")
    build_rel = os.path.join("WorkshopModules", "scripts", "build_modules.sh")
    controller_text = read_text(os.path.join(ROOT, controller_rel))
    display_text = read_text(os.path.join(ROOT, display_rel))
    core_text = read_text(os.path.join(ROOT, core_rel))
    build_text = read_text(os.path.join(ROOT, build_rel))
    for fragment in [
        "Вставить картридж",
        "setAllowedFileTypes:",
        "quicknes_libretro",
        "genesis_plus_gx_libretro",
    ]:
        if fragment not in controller_text:
            errors.append("%s: retro cartridge flow is missing `%s`" %
                          (controller_rel, fragment))
    for fragment in ["NSFilenamesPboardType", "performDragOperation:", "keyDown:", "keyUp:"]:
        if fragment not in display_text:
            errors.append("%s: retro drag/drop or keyboard input is missing `%s`" %
                          (display_rel, fragment))
    for fragment in ["dlopen", "retro_load_game", "AudioOutputUnitStart", "renderAudioFrames:"]:
        if fragment not in core_text:
            errors.append("%s: retro runtime is missing `%s`" % (core_rel, fragment))
    for fragment in ["QUICKNES_CORE_PATH", "GENESIS_PLUS_GX_CORE_PATH", 'build_module "RetroConsole"']:
        if fragment not in build_text:
            errors.append("%s: retro core packaging is missing `%s`" % (build_rel, fragment))

    forbidden_extensions = (".nes", ".smd", ".gen", ".sms", ".gg", ".sg")
    for directory, _, filenames in os.walk(os.path.join(ROOT, module_rel)):
        for filename in filenames:
            if filename.lower().endswith(forbidden_extensions):
                errors.append("%s: game images must never be bundled" %
                              os.path.relpath(os.path.join(directory, filename), ROOT))


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
    check_conversation_creation_contract(errors)
    check_composer_formatting_contract(errors)
    check_additional_message_types_contract(errors)
    check_media_file_management_contract(errors)
    check_primary_navigation_contract(errors)
    check_retro_console_contract(errors)
    if errors:
        print("Static project tests failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Static project tests passed: localization, project membership, test structure, local-data guard.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
