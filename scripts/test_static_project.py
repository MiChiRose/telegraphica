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


def check_text_interaction_contract(errors):
    navigation_rel = os.path.join("Sources", "UI", "TGStatusWindowController+SearchNavigation.inc")
    navigation_text = read_text(os.path.join(ROOT, navigation_rel))
    for fragment in [
        "routeTextEditingKeyEquivalent:",
        "shortcutFlags != NSCommandKeyMask",
        "[NSApp sendAction:action to:textView from:self]",
    ]:
        if fragment not in navigation_text:
            errors.append("%s: exact text shortcut routing is missing `%s`" %
                          (navigation_rel, fragment))

    components_rel = os.path.join("Sources", "UI", "TGStatusViewComponents.m")
    components_text = read_text(os.path.join(ROOT, components_rel))
    for fragment in [
        "clearSelectableMessageText",
        "selectableTextDescriptorAtPoint:",
        "[textView setSelectable:YES]",
        "selectedRange].length > 0",
    ]:
        if fragment not in components_text:
            errors.append("%s: selectable message text support is missing `%s`" %
                          (components_rel, fragment))


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

    location_picker_rel = os.path.join("Sources", "UI", "TGLocationPickerWindowController.m")
    location_picker_text = read_text(os.path.join(ROOT, location_picker_rel))
    for fragment in ["NSClassFromString(@\"MKMapView\")",
                     "setShowsUserLocation:YES",
                     "TGLocationStaticMapView",
                     "MKPinAnnotationView",
                     "reloadMapThumbnail",
                     "prepareForClosing",
                     "setCoordinateTarget:nil",
                     "self.mapGeneration++;",
                     "setShowsUserLocation:NO",
                     "setDelegate:nil",
                     "TGLocationSearchService",
                     "searchPressed:",
                     "[self.searchService cancel]",
                     "mapUnavailable"]:
        if fragment not in location_picker_text:
            errors.append("%s: location picker regression guard is missing `%s`" %
                          (location_picker_rel, fragment))
    if location_picker_text.count("[self prepareForClosing];") != 3:
        errors.append("%s: Send, Cancel and window close must all prepare the location picker for closing" %
                      location_picker_rel)
    for fragment in ["MKLocalSearchRequest",
                     "MKLocalSearch",
                     "CLGeocoder"]:
        if fragment in location_picker_text:
            errors.append("%s: MapKit search lifecycle must stay in the focused service, found `%s`" %
                          (location_picker_rel, fragment))

    location_search_rel = os.path.join("Sources", "UI", "TGLocationSearchService.m")
    location_search_text = read_text(os.path.join(ROOT, location_search_rel))
    for fragment in ["TGLocationSearchOperation",
                     "MKLocalSearchRequest",
                     "startWithCompletionHandler:",
                     "[operation cancel]",
                     "self.completion = nil",
                     "[self.activeSearch cancel]",
                     "NSClassFromString(@\"MKLocalSearch\")"]:
        if fragment not in location_search_text:
            errors.append("%s: lifecycle-safe location search is missing `%s`" %
                          (location_search_rel, fragment))
    if "CLGeocoder" in location_search_text:
        errors.append("%s: nested CLGeocoder fallback must not bypass search cancellation" %
                      location_search_rel)

    static_map_rel = os.path.join("Sources", "UI", "TGLocationStaticMapView.m")
    static_map_text = read_text(os.path.join(ROOT, static_map_rel))
    for fragment in ["openHandCursor",
                     "closedHandCursor",
                     "dragThreshold = 6.0",
                     "scrollWheel:",
                     "hasPreciseScrollingDeltas",
                     "magnifyWithEvent:",
                     "requestZoomDelta:",
                     "coordinateForPoint:",
                     "selectionPinImage"]:
        if fragment not in static_map_text:
            errors.append("%s: interactive map fallback is missing `%s`" %
                          (static_map_rel, fragment))

    location_messages_rel = os.path.join("Sources", "Core", "TGTDLibClient+LocationMessages.m")
    location_messages_text = read_text(os.path.join(ROOT, location_messages_rel))
    for fragment in ["messageLocation",
                     "messageVenue",
                     "mapThumbnailPathForLatitude:",
                     'path, @"local_path"']:
        if fragment not in location_messages_text:
            errors.append("%s: location message thumbnail support is missing `%s`" %
                          (location_messages_rel, fragment))

    date_picker_rel = os.path.join("Sources", "UI", "TGDatePickerDialog.m")
    date_picker_text = read_text(os.path.join(ROOT, date_picker_rel))
    if "NSTextFieldAndStepperDatePickerStyle" not in date_picker_text:
        errors.append("%s: compact legacy-safe date picker style is missing" % date_picker_rel)

    saved_cell_rel = os.path.join("Sources", "UI", "TGSavedMessagesCell.m")
    saved_cell_text = read_text(os.path.join(ROOT, saved_cell_rel))
    for fragment in ["objectForKey:@\"title\"", "objectForKey:@\"detail\"",
                     "NSLineBreakByTruncatingTail"]:
        if fragment not in saved_cell_text:
            errors.append("%s: saved-message row rendering is missing `%s`" %
                          (saved_cell_rel, fragment))

    bot_composer_rel = os.path.join("Sources", "UI", "TGStatusWindowController+BotComposer.inc")
    bot_composer_text = read_text(os.path.join(ROOT, bot_composer_rel))
    for fragment in ["setBotComposerVisible", "replyMarkupShowKeyboard",
                     "setBotCommandPanelVisible", "setDuration:0.16"]:
        if fragment not in bot_composer_text:
            errors.append("%s: bot composer integration is missing `%s`" %
                          (bot_composer_rel, fragment))

    composer_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ComposerMedia.inc")
    composer_text = read_text(os.path.join(ROOT, composer_rel))
    for fragment in ["shareContactFromComposerMenu:", "shareLocationFromComposerMenu:",
                     "sendAnimationMessageToChatID:",
                     "refreshSelectedMessagesAfterMediaSend"]:
        if fragment not in composer_text:
            errors.append("%s: composer message-type routing is missing `%s`" %
                          (composer_rel, fragment))
    if "refreshSelectedChatMessages:" in composer_text:
        errors.append("%s: removed media refresh selector was reintroduced" % composer_rel)

    calls_rel = os.path.join("Sources", "Core", "TGTDLibClient+Calls.m")
    calls_text = read_text(os.path.join(ROOT, calls_rel))
    for fragment in ['@"createCall"', '@"acceptCall"', '@"discardCall"',
                     '@"sendCallSignalingData"', '@"min_layer"', '@"max_layer"',
                     "[TGCallAudioEngine protocolVersions]",
                     "[TGCallAudioEngine maximumProtocolLayer]",
                     '[NSNumber numberWithBool:isVideo], @"is_video"',
                     "createCallToUserID:userID isVideo:NO"]:
        if fragment not in calls_text:
            errors.append("%s: free audio-call signaling is missing `%s`" %
                          (calls_rel, fragment))


def check_call_transport_stability_contract(errors):
    audio_rel = os.path.join("Sources", "Calls", "TGCallAudioEngine.mm")
    audio_text = read_text(os.path.join(ROOT, audio_rel))
    relay_lookup = "int64_t relayID = api->preferredRelayID(_transport);"
    transport_stop = "api->stop(_transport);"
    if relay_lookup not in audio_text or transport_stop not in audio_text:
        errors.append("%s: relay shutdown contract is incomplete" % audio_rel)
    elif audio_text.find(relay_lookup) > audio_text.find(transport_stop):
        errors.append("%s: relay ID must be captured before modern transport stop invalidates its instance" %
                      audio_rel)
    for fragment in [
        "TGSystemSupportsModernTelegramAudioCalls()",
        "TelegraphicaCallTransport.dylib",
        "TGModernCallTransportABIVersion",
        "TGModernCallTransportReceiveSignalingData",
        "TGModernCallTransportSetMicrophoneMuted",
        "TGModernCallTransportSetSpeakerMuted",
        "TGModernCallTransportSetCameraEnabled",
        "TGModernCallTransportPreferredRelayID",
        "TGModernCallTransportStop",
        "didEmitSignalingData:",
        "didReceiveVideoImage:",
    ]:
        if fragment not in audio_text:
            errors.append("%s: modern call-audio contract is missing `%s`" %
                          (audio_rel, fragment))

    modern_header_rel = os.path.join("ModernCallTransport", "TGModernCallTransport.h")
    modern_source_rel = os.path.join("ModernCallTransport", "TGModernCallTransport.mm")
    modern_video_rel = os.path.join("ModernCallTransport", "TGModernCallVideoPlatform.cpp")
    modern_cmake_rel = os.path.join("ModernCallTransport", "CMakeLists.txt")
    verified_transport_rel = os.path.join(
        "ModernCallTransport", "VERIFIED_TRANSPORT.sha256")
    modern_header_text = read_text(os.path.join(ROOT, modern_header_rel))
    modern_source_text = read_text(os.path.join(ROOT, modern_source_rel))
    modern_video_text = read_text(os.path.join(ROOT, modern_video_rel))
    modern_cmake_text = read_text(os.path.join(ROOT, modern_cmake_rel))
    verified_transport_text = read_text(
        os.path.join(ROOT, verified_transport_rel))
    expected_transport_sha = (
        "96713ab9689d8e79c0caa7c8985e88d31fcfee2a235134e92f5c622250f9677e")
    if expected_transport_sha not in verified_transport_text:
        errors.append(
            "%s: the HITL-approved audio-call transport hash changed" %
            verified_transport_rel)
    for fragment in [
        "TG_MODERN_CALL_TRANSPORT_ABI_VERSION",
        "TGModernCallTransportCreate",
        "TGModernCallTransportReceiveSignalingData",
    ]:
        if fragment not in modern_header_text:
            errors.append("%s: modern transport ABI is missing `%s`" %
                          (modern_header_rel, fragment))
    for fragment in [
        '"9.0.0,8.0.0,7.0.0,3.0.0,2.7.7"',
        "descriptor.signalingDataEmitted",
        "descriptor.config.enableAEC = true",
        "descriptor.config.enableNS = true",
        "descriptor.config.enableAGC = true",
        "MutingAudioTransport",
        "MutingAudioDeviceModule",
        "audioOutputState->muted.store",
        "libyuv::I420Rotate",
        "libyuv::I420ToBGRA",
        "now - _lastFrameAt).count() < 120",
        "width > 480 || height > 360",
        "does not change the encoded video sent",
        "remotePrefferedAspectRatioUpdated = [rawOwner]",
        "Local camera capture failed",
    ]:
        if fragment not in modern_source_text:
            errors.append("%s: modern Telegram transport is missing `%s`" %
                          (modern_source_rel, fragment))
    for fragment in [
        "AppendCapabilityWithI420Fallback",
        "NumberOfCapabilities(selectedID.c_str())",
        "StartCapture(candidate)",
    ]:
        if fragment not in modern_video_text:
            errors.append("%s: legacy camera fallback is missing `%s`" %
                          (modern_video_rel, fragment))
    for fragment in [
        "CMAKE_OSX_DEPLOYMENT_TARGET 10.9",
        'OUTPUT_NAME "TelegraphicaCallTransport"',
        'PREFIX ""',
        "webrtc::AudioProcessingBuilder audioProcessingBuilder",
        "mediaDeps.audio_processing = audioProcessingBuilder.Create()",
        "candidateAddress.SetResolvedIP(server_address_.address.ipaddr())",
        "TGReflectorPortPatched.cpp",
    ]:
        if fragment not in modern_cmake_text:
            errors.append("%s: Mavericks transport build is missing `%s`" %
                          (modern_cmake_rel, fragment))

    build_rel = "build_legacy.sh"
    build_text = read_text(os.path.join(ROOT, build_rel))
    for fragment in [
        "TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH",
        "ModernCallTransport/VERIFIED_TRANSPORT.sha256",
        "TELEGRAPHICA_ALLOW_UNVERIFIED_CALL_TRANSPORT",
        "Refusing to replace the HITL-verified audio-call transport.",
        'CALL_TRANSPORT_MIN" != "10.9"',
        "TelegraphicaCallTransport.dylib",
        "TELEGRAPHICA_LIBTGVOIP_SOURCE is ignored",
    ]:
        if fragment not in build_text:
            errors.append("%s: unified call-module packaging is missing `%s`" %
                          (build_rel, fragment))
    for forbidden in ["TgVoip.h", "TgVoip.cpp", "TELEGRAPHICA_HAS_TGVOIP"]:
        if forbidden in audio_text or forbidden in build_text:
            errors.append("legacy libtgvoip transport was reintroduced via `%s`" % forbidden)

    release_rel = os.path.join(
        "scripts", "package_legacy_release_artifacts.sh")
    release_text = read_text(os.path.join(ROOT, release_rel))
    for fragment in [
        "TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH",
        "The HITL-verified OS X 10.9+ audio-call transport was not found.",
        "Refusing to package a public release with an unverified audio-call transport.",
    ]:
        if fragment not in release_text:
            errors.append("%s: verified call transport release guard is missing `%s`" %
                          (release_rel, fragment))

    window_rel = os.path.join("Sources", "Calls", "TGCallWindowController.m")
    window_text = read_text(os.path.join(ROOT, window_rel))
    if "cell->_actionColor = [_actionColor retain];" not in window_text:
        errors.append("%s: legacy NSCell copies must retain the bit-copied action color directly" %
                      window_rel)
    if "cell.actionColor = self.actionColor;" in window_text:
        errors.append("%s: synthesized setters over-release bit-copied NSCell subclass ivars" %
                      window_rel)
    for fragment in [
        "updateSignalBars:",
        "layoutQualityIndicator",
        "layoutStatusForConnectedState:",
        'TGLoc(@"calls.quality")',
        "[self.qualityField setHidden:!connected]",
        'iconName:@"headphones"',
        'self.speakerMuted ? @"headphones-off" : @"headphones"',
        'self.microphoneMuted ? @"microphone-off" : @"microphone"',
        '[NSSound soundNamed:@"Marimba"]',
        'Ringtones/Marimba.m4r',
        'Application Support/Telegraphica/Sounds/Marimba.m4r',
        '~/Library/Sounds/Marimba.m4r',
        "if (state == TGCallPresentationStateIncoming)",
    ]:
        if fragment not in window_text:
            errors.append("%s: call presentation contract is missing `%s`" %
                          (window_rel, fragment))
    for forbidden_fallback in ['soundNamed:@"Funk"', 'soundNamed:@"Pop"']:
        if forbidden_fallback in window_text:
            errors.append("%s: non-Marimba ringtone fallback must not masquerade as Marimba `%s`" %
                          (window_rel, forbidden_fallback))
    if "state == TGCallPresentationStateCalling || state == TGCallPresentationStateIncoming" in window_text:
        errors.append("%s: outgoing calls must not play the incoming Marimba ringtone" % window_rel)

    coordinator_rel = os.path.join("Sources", "Calls", "TGCallCoordinator.m")
    coordinator_text = read_text(os.path.join(ROOT, coordinator_rel))
    for fragment in [
        '#import "../Services/TGPrivacyPermissions.h"',
        "[TGPrivacyPermissions requestMicrophonePermission]",
        "callNegotiationDidTimeout",
        'TGLoc(@"calls.negotiationTimeout")',
        "Audio call: TDLib state",
        "Audio call: media transport established.",
        "TGTDLibCallSignalingDataDidUpdateNotification",
        "sendAudioCallSignalingData:",
        "receiveSignalingData:",
    ]:
        if fragment not in coordinator_text:
            errors.append("%s: call negotiation diagnostics are missing `%s`" %
                          (coordinator_rel, fragment))
    if "descriptor.config.allowTCP = true;" not in modern_source_text:
        errors.append("%s: Telegram call transport must retain TCP relay fallback" %
                      modern_source_rel)
    if "setRequestedVideoAspect(4.0f / 3.0f)" in modern_source_text:
        errors.append("%s: fixed 4:3 incoming-video requests distort portrait callers" %
                      modern_source_rel)

    privacy_permissions_rel = os.path.join(
        "Sources", "Services", "TGPrivacyPermissions.m")
    privacy_permissions_text = read_text(
        os.path.join(ROOT, privacy_permissions_rel))
    for fragment in [
        "requestMicrophonePermission",
        "requestLocationPermission",
        "TGPrivacyPermissionsDidChangeNotification",
        "TelegraphicaMicrophonePermissionDecisionV2",
        "TelegraphicaLocationPermissionDecisionV1",
    ]:
        if fragment not in privacy_permissions_text:
            errors.append("%s: app permission contract is missing `%s`" %
                          (privacy_permissions_rel, fragment))

    privacy_window_rel = os.path.join(
        "Sources", "UI", "TGPrivacyWindowController.m")
    privacy_window_text = read_text(os.path.join(ROOT, privacy_window_rel))
    for fragment in [
        "microphonePermissionButton",
        "locationPermissionButton",
        'TGLoc(@"privacy.permissions.title")',
        "[TGPrivacyPermissions setMicrophoneAllowed:",
        "[TGPrivacyPermissions setLocationAllowed:",
    ]:
        if fragment not in privacy_window_text:
            errors.append("%s: permission settings UI is missing `%s`" %
                          (privacy_window_rel, fragment))

    location_picker_rel = os.path.join(
        "Sources", "UI", "TGLocationPickerWindowController.m")
    location_picker_text = read_text(os.path.join(ROOT, location_picker_rel))
    if "[TGPrivacyPermissions requestLocationPermission]" not in location_picker_text:
        errors.append("%s: current-location lookup bypasses app permission" %
                      location_picker_rel)

    history_rel = os.path.join("Sources", "UI", "TGCallsPlaceholderView.m")
    history_text = read_text(os.path.join(ROOT, history_rel))
    if "cell->_callSummary = [_callSummary retain];" not in history_text:
        errors.append("%s: call history cells must own copied row summaries on legacy AppKit" %
                      history_rel)
    for fragment in ['@"call-in"', '@"call-out"', '@"call-miss"']:
        if fragment not in history_text:
            errors.append("%s: call history direction icon is missing `%s`" %
                          (history_rel, fragment))
    for fragment in [
        "NSHeight(frame) - 83.0",
        "NSHeight(frame) - 118.0",
        "NSHeight(frame) - 150.0",
        "NSHeight(frame) - 202.0",
        "historyScrollView",
        'TGLoc(@"calls.selectContact")',
        "[self.startCallButton setEnabled:NO]",
        "@selector(contactSelectionChanged:)",
    ]:
        if fragment not in history_text:
            errors.append("%s: compact call-history layout is missing `%s`" %
                          (history_rel, fragment))
    for forbidden_fragment in [
        "mockOutgoingButton",
        "mockIncomingButton",
        "@selector(mockOutgoingPressed:)",
        "@selector(mockIncomingPressed:)",
    ]:
        if forbidden_fragment in history_text:
            errors.append("%s: demo call controls must not be visible in the production calls screen `%s`" %
                          (history_rel, forbidden_fragment))
    if "[self.unavailableDetailField setLineBreakMode:" in history_text:
        errors.append("%s: legacy NSTextField line breaking must be configured through its cell" %
                      history_rel)
    for fragment in [
        "@interface TGCallHistoryTableView : NSTableView",
        "- (NSMenu *)menuForEvent:(NSEvent *)event",
        "@selector(deleteRecentCallPressed:)",
        'initWithTitle:TGLoc(@"delete")',
        "messageIDs:[NSArray arrayWithObject:retainedMessageID]",
        "revoke:NO",
    ]:
        if fragment not in history_text:
            errors.append("%s: call-history deletion contract is missing `%s`" %
                          (history_rel, fragment))
    calls_rel = os.path.join("Sources", "Core", "TGTDLibClient+Calls.m")
    calls_text = read_text(os.path.join(ROOT, calls_rel))
    for fragment in ['forKey:@"chat_id"', 'forKey:@"message_id"']:
        if fragment not in calls_text:
            errors.append("%s: call summaries must preserve the deletion target `%s`" %
                          (calls_rel, fragment))
    for icon_name in [
        "call-cancel.png",
        "call-in.png",
        "call-miss.png",
        "call-out.png",
        "headphones-off.png",
        "headphones.png",
        "microphone-off.png",
    ]:
        icon_path = os.path.join(ROOT, "Sources", "Resources", "Icons", icon_name)
        if not os.path.isfile(icon_path):
            errors.append("Sources/Resources/Icons/%s: approved call-control icon is missing" %
                          icon_name)

    media_windows_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MediaWindows.inc")
    media_windows_text = read_text(os.path.join(ROOT, media_windows_rel))
    playback_start = media_windows_text.find("- (void)openPlayableMediaForMediaItem:")
    playback_end = media_windows_text.find("- (void)layoutMediaPreviewWindowControls")
    playback_text = media_windows_text[playback_start:playback_end] if (
        playback_start >= 0 and playback_end > playback_start) else ""
    if not playback_text:
        errors.append("%s: playable-media method group could not be inspected" %
                      media_windows_rel)
    for forbidden in [
        "path = TGMediaCenterLocalPathForItem(item);",
        "path = TGMediaItemLocalPath(mediaItem);",
    ]:
        if forbidden in playback_text:
            errors.append("%s: visual thumbnails must not be passed to AVPlayer via `%s`" %
                          (media_windows_rel, forbidden))
    if "path = TGMediaItemPlayableLocalPath(fallbackMedia);" not in playback_text:
        errors.append("%s: message playback must validate its fallback local path" %
                      media_windows_rel)
    for fragment in [
        "layoutMediaPlaybackChromeForAudioOnly:",
        "setContentSize:NSMakeSize(480.0, 170.0)",
        "setMinSize:NSMakeSize(440.0, 178.0)",
    ]:
        if fragment not in media_windows_text:
            errors.append("%s: voice playback layout is missing `%s`" %
                          (media_windows_rel, fragment))


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
        "TGDownloadManager sharedManager",
        "mediaCenterSavedPathsByFileID",
        'TGLoc(@"media.center.downloadedTo")',
    ]:
        if fragment not in media_text:
            errors.append("%s: Media Center file action routing is missing `%s`" %
                          (media_rel, fragment))
    if "removeItemAtPath:path error:&error" in media_text:
        errors.append("%s: Media Center must delete cached files through TDLib, not unlink cache paths directly" %
                      media_rel)

    manager_rel = os.path.join("Sources", "Services", "TGDownloadManager.m")
    manager_text = read_text(os.path.join(ROOT, manager_rel))
    for fragment in [
        "TGConfiguredDownloadFolderPath()",
        "saveCopyOfFileAtPath:",
        "cancelDownloadForFileID:",
        "TGDownloadManagerDidChangeNotification",
    ]:
        if fragment not in manager_text:
            errors.append("%s: shared Download Manager is missing `%s`" %
                          (manager_rel, fragment))


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
    cells_header_rel = os.path.join("Sources", "UI", "TGStatusViewCells.h")
    cells_header_text = read_text(os.path.join(ROOT, cells_header_rel))
    cells_impl_rel = os.path.join("Sources", "UI", "TGStatusViewCells.m")
    cells_impl_text = read_text(os.path.join(ROOT, cells_impl_rel))
    for fragment in [
        "contactSummariesWithTimeout:",
        "privateChatIDForUserID:",
        "userProfileSummaryForUserID:",
        "applySearchFilter",
        "loadSelectedContactProfile",
        "TGContactProfileView",
        "TGDrawAvatarInRect",
        "contactsViewControllerDidRequestNewConversation:",
    ]:
        if fragment not in contacts_text:
            errors.append("%s: contacts section is missing `%s`" %
                          (contacts_rel, fragment))
    for fragment in [
        "TGRepresentedObjectCell",
        "representedObject",
    ]:
        if fragment not in cells_header_text or fragment not in cells_impl_text:
            errors.append("%s: legacy model-backed table cell is missing `%s`" %
                          (cells_impl_rel, fragment))
    if "@interface TGContactRowCell : TGRepresentedObjectCell" not in contacts_text:
        errors.append("%s: contact rows must preserve dictionary models on legacy AppKit" %
                      contacts_rel)

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
        "NSRectFillUsingOperation(clipRect, NSCompositeCopy)",
        "CGFloat documentHeight = MAX(1.0, ((CGFloat)[_results count] * rowExtent))",
        "[_scrollView setHasVerticalScroller:needsVerticalScroller]",
        "NSArray *snapshot = results ? [[NSArray alloc] initWithArray:results]",
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
        "@interface TGChatLifecycleContactCell : TGRepresentedObjectCell",
        "TGDrawAvatarInRect",
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
    tdlib_client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    tdlib_client_text = read_text(os.path.join(ROOT, tdlib_client_rel))
    for fragment in [
        "setName",
        "setUsername",
        "setBio",
        "setProfilePhoto",
        "inputChatPhotoStatic",
        "inputFileLocal",
        "updateCurrentUserFirstName",
        "setCurrentUserProfilePhotoAtPath",
    ]:
        if fragment not in client_text:
            errors.append("%s: profile editing TDLib request is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "TGProfileEditWindowController",
        "TGPrimaryTextButtonCell",
        "profile.edit.firstNameRequired",
        "profile.edit.photo.choose",
        "TGPreparedProfilePhotoPath",
        "didRequestSetPhotoAtPath",
    ]:
        if fragment not in profile_editor_text:
            errors.append("%s: profile editor is missing `%s`" %
                          (profile_editor_rel, fragment))
    for fragment in [
        "showProfileEditWindow:",
        "didRequestSaveFirstName:",
        "didRequestSetPhotoAtPath:",
        "reloadProfileSummaryIfReady",
        "[NSApp activateIgnoringOtherApps:YES]",
        'log:@"Profile editor presented."',
    ]:
        if fragment not in utility_windows_text:
            errors.append("%s: profile editor wiring is missing `%s`" %
                          (utility_windows_rel, fragment))
    profile_button_cell_index = controller_text.find(
        "[self.profileEditButton setCell:")
    profile_button_action_index = controller_text.find(
        "[self.profileEditButton setAction:@selector(showProfileEditWindow:)]")
    if profile_button_cell_index < 0 or profile_button_action_index < 0:
        errors.append("%s: profile edit button wiring is incomplete" % controller_rel)
    elif profile_button_action_index < profile_button_cell_index:
        errors.append("%s: profile edit button cell replacement must happen before target/action wiring" %
                      controller_rel)
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
        "parametersErrorCode",
        "login.keychain.title",
        "login.keychain.required",
    ]:
        if fragment not in message_data_flow_text:
            errors.append("%s: Keychain bootstrap failure UI is missing `%s`" %
                          (message_data_flow_rel, fragment))
    if "mainThreadError = [keychainError retain]" not in tdlib_client_text:
        errors.append("%s: the Mavericks MRC Keychain error must survive the main-thread handoff" %
                      tdlib_client_rel)
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
        u"Вставить картридж",
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


def check_chat_archive_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    controller_rel = os.path.join("Sources", "UI", "TGStatusWindowController.m")
    data_flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageDataFlow.inc")
    menus_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    lifecycle_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ChatLifecycle.inc")
    buttons_rel = os.path.join("Sources", "UI", "TGStatusButtonCells.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    controller_text = read_text(os.path.join(ROOT, controller_rel))
    data_flow_text = read_text(os.path.join(ROOT, data_flow_rel))
    menus_text = read_text(os.path.join(ROOT, menus_rel))
    lifecycle_text = read_text(os.path.join(ROOT, lifecycle_rel))
    buttons_text = read_text(os.path.join(ROOT, buttons_rel))

    for fragment in [
        '"addChatToList"',
        '"chatListArchive"',
        "archivedChatPreviewItemsWithLimit:",
        "archivedChatIDsWithLimit:",
    ]:
        if fragment not in client_text:
            errors.append("%s: chat archive TDLib contract is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "showingArchivedChats",
        'TGLoc(@"drawer.archive")',
        "[NSNumber numberWithInteger:-2]",
    ]:
        if fragment not in controller_text:
            errors.append("%s: archive drawer state is missing `%s`" %
                          (controller_rel, fragment))
    if "loadingArchivedChats != self.showingArchivedChats" not in data_flow_text:
        errors.append("%s: archive loads must reject stale list results" % data_flow_rel)
    if 'TGTemplateIconAssetImage(@"archive"' not in menus_text:
        errors.append("%s: archive menu must reuse the existing archive icon asset" % menus_rel)
    if "toggleChatArchivedFromMenu:" not in lifecycle_text:
        errors.append("%s: archive action wiring is missing" % lifecycle_rel)
    if 'TGDrawTemplateIconAsset(@"archive"' not in buttons_text:
        errors.append("%s: archive drawer must reuse the existing archive icon asset" % buttons_rel)
    archive_icon = os.path.join(ROOT, "Sources", "Resources", "Icons", "archive.png")
    if not os.path.isfile(archive_icon):
        errors.append("Sources/Resources/Icons/archive.png: required existing archive icon is missing")


def check_chat_history_deletion_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient+ChatHistory.m")
    client_text = read_text(os.path.join(ROOT, client_rel))
    for fragment in [
        '@"deleteChatHistory", @"@type"',
        '@"chat_id"',
        '@"remove_from_chat_list"',
        '@"revoke"',
        'isEqualToString:@"ok"',
    ]:
        if fragment not in client_text:
            errors.append("%s: chat history deletion request is missing `%s`" %
                          (client_rel, fragment))

    lifecycle_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ChatLifecycle.inc")
    lifecycle_text = read_text(os.path.join(ROOT, lifecycle_rel))
    for fragment in [
        "clearChatHistoryFromMenu:",
        "NSCriticalAlertStyle",
        'TGLoc(@"chat.clearHistoryConfirmTitle")',
        "removeFromChatList:NO",
        "revoke:NO",
        "[self.messageItems removeAllObjects]",
    ]:
        if fragment not in lifecycle_text:
            errors.append("%s: safe clear-history flow is missing `%s`" %
                          (lifecycle_rel, fragment))

    menus_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    menus_text = read_text(os.path.join(ROOT, menus_rel))
    for fragment in [
        'TGLoc(@"chat.clearHistory")',
        "@selector(clearChatHistoryFromMenu:)",
        'TGLoc(@"chat.delete")',
        "@selector(deletePrivateChatFromMenu:)",
        'TGTemplateIconAssetImage(@"trash"',
    ]:
        if fragment not in menus_text:
            errors.append("%s: clear-history menu is missing `%s`" %
                          (menus_rel, fragment))
    for fragment in [
        "deletePrivateChatFromMenu:",
        "removeFromChatList:YES",
        'TGLoc(@"chat.deleteConfirmTitle")',
        'TGLoc(@"chat.deleteConfirm")',
    ]:
        if fragment not in lifecycle_text:
            errors.append("%s: private-chat removal flow is missing `%s`" %
                          (lifecycle_rel, fragment))


def check_chat_navigation_actions_contract(errors):
    item_rel = os.path.join("Sources", "Core", "TGChatItem.h")
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    menus_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    cells_rel = os.path.join("Sources", "UI", "TGStatusViewCells.m")
    item_text = read_text(os.path.join(ROOT, item_rel))
    client_text = read_text(os.path.join(ROOT, client_rel))
    menus_text = read_text(os.path.join(ROOT, menus_rel))
    cells_text = read_text(os.path.join(ROOT, cells_rel))

    if "isMarkedAsUnread" not in item_text:
        errors.append("%s: manually unread chat state is missing" % item_rel)
    for fragment in ['@"toggleChatIsMarkedAsUnread"', '@"is_marked_as_unread"',
                     '@"getChatMessageByDate"', '@"date"']:
        if fragment not in client_text:
            errors.append("%s: chat navigation TDLib contract is missing `%s`" %
                          (client_rel, fragment))
    for fragment in ["toggleChatReadStateFromMenu:", "markChatItemUnread:",
                     "jumpToChatDateFromMenu:", "jumpToSearchResult:"]:
        if fragment not in menus_text:
            errors.append("%s: chat navigation action is missing `%s`" %
                          (menus_rel, fragment))
    for fragment in ["drawsMarkedUnreadDot", "TGColorFromHex(0x2D8BD4)"]:
        if fragment not in cells_text:
            errors.append("%s: manually unread chat indicator is missing `%s`" %
                          (cells_rel, fragment))


def check_message_link_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient+MessageLinks.m")
    menu_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    project_rel = os.path.join("Telegraphica.xcodeproj", "project.pbxproj")
    client_text = read_text(os.path.join(ROOT, client_rel))
    menu_text = read_text(os.path.join(ROOT, menu_rel))
    project_text = read_text(os.path.join(ROOT, project_rel))

    for fragment in ['@"getMessageLink"', '@"in_message_thread"', '@"for_comment"',
                     '@"messageLink"', '@"link"']:
        if fragment not in client_text:
            errors.append("%s: TDLib message-link compatibility is missing `%s`" %
                          (client_rel, fragment))
    for fragment in ["copyMessageLinkFromMenu:", 'TGLoc(@"message.copyLink")',
                     "messageLinkForChatID:", "NSPasteboard"]:
        if fragment not in menu_text:
            errors.append("%s: message-link menu action is missing `%s`" %
                          (menu_rel, fragment))
    if "TGTDLibClient+MessageLinks.m in Sources" not in project_text:
        errors.append("%s: message-link client category is not compiled" % project_rel)


def check_composer_link_editor_contract(errors):
    support_rel = os.path.join("Sources", "UI", "TGComposerLinkSupport.m")
    composer_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ComposerMedia.inc")
    localization_rel = os.path.join("Sources", "UI", "TGLocalization.m")
    project_rel = os.path.join("Telegraphica.xcodeproj", "project.pbxproj")
    support_text = read_text(os.path.join(ROOT, support_rel))
    composer_text = read_text(os.path.join(ROOT, composer_rel))
    localization_text = read_text(os.path.join(ROOT, localization_rel))
    project_text = read_text(os.path.join(ROOT, project_rel))

    for fragment in [
        "TGComposerLinkInfoForTextSelection",
        "TGComposerMarkdownLinkString",
        "TGComposerPromptForLinkURL",
        'stringByAppendingString:candidate',
        '[scheme isEqualToString:@"tg"]',
    ]:
        if fragment not in support_text:
            errors.append("%s: composer link support is missing `%s`" %
                          (support_rel, fragment))
    for fragment in [
        "applyComposerLink:",
        "removeComposerLink:",
        'TGLoc(@"composer.link.add")',
        'TGLoc(@"composer.link.remove")',
        'NSString *sentinel = @"\\u2063"',
    ]:
        if fragment not in composer_text:
            errors.append("%s: composer link editor wiring is missing `%s`" %
                          (composer_rel, fragment))
    for key in [
        "composer.link.add",
        "composer.link.edit",
        "composer.link.remove",
        "composer.link.invalid",
    ]:
        if localization_text.count('@"%s"' % key) != 3:
            errors.append("%s: composer link localization `%s` must exist in all three languages" %
                          (localization_rel, key))
    if "TGComposerLinkSupport.m in Sources" not in project_text:
        errors.append("%s: composer link support is not compiled" % project_rel)


def check_hourly_update_check_contract(errors):
    scheduler_rel = os.path.join("Sources", "Services", "TGUpdateCheckScheduler.m")
    scheduler_text = read_text(os.path.join(ROOT, scheduler_rel))
    for fragment in [
        "timerWithTimeInterval:_interval",
        "NSRunLoopCommonModes",
        "startWithInitialDelay:",
        "resetCountdown",
        "[self.timer invalidate]",
    ]:
        if fragment not in scheduler_text:
            errors.append("%s: background update scheduler is missing `%s`" %
                          (scheduler_rel, fragment))

    controller_rel = os.path.join("Sources", "UI", "TGStatusWindowController.m")
    controller_text = read_text(os.path.join(ROOT, controller_rel))
    for fragment in [
        "TGBackgroundUpdateCheckInterval = (60.0 * 60.0)",
        "TGUpdateCheckScheduler",
        "initialUpdateCheckDelay",
        "startWithInitialDelay:initialUpdateCheckDelay",
        "updateCheckInFlight",
    ]:
        if fragment not in controller_text:
            errors.append("%s: hourly update-check wiring is missing `%s`" %
                          (controller_rel, fragment))

    notifications_rel = os.path.join("Sources", "UI", "TGStatusWindowController+Notifications.inc")
    notifications_text = read_text(os.path.join(ROOT, notifications_rel))
    for fragment in [
        "if (self.updateCheckInFlight)",
        "(now - last) < TGBackgroundUpdateCheckInterval",
        "[self.updateCheckScheduler resetCountdown]",
        "self.updateCheckInFlight = NO",
        'NSString *badgeText = self.updateAvailable ? @"1" : nil',
        "setBadgeText:badgeText",
    ]:
        if fragment not in notifications_text:
            errors.append("%s: hourly update-check behavior is missing `%s`" %
                          (notifications_rel, fragment))
    if "(24.0 * 60.0 * 60.0)" in notifications_text:
        errors.append("%s: automatic update checks must no longer use the old 24-hour throttle" %
                      notifications_rel)


def check_chat_folder_management_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient+ChatFolders.m")
    controller_rel = os.path.join("Sources", "UI", "TGChatFolderManagementWindowController.m")
    host_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ChatFolders.inc")
    status_rel = os.path.join("Sources", "UI", "TGStatusWindowController.m")
    layout_rel = os.path.join("Sources", "UI", "TGStatusWindowController+SectionLayout.inc")
    client_text = read_text(os.path.join(ROOT, client_rel))
    controller_text = read_text(os.path.join(ROOT, controller_rel))
    host_text = read_text(os.path.join(ROOT, host_rel))
    status_text = read_text(os.path.join(ROOT, status_rel))
    layout_text = read_text(os.path.join(ROOT, layout_rel))

    for fragment in [
        '"createChatFolder"',
        '"editChatFolder"',
        '"deleteChatFolder"',
        '"createChatFilter"',
        '"editChatFilter"',
        '"deleteChatFilter"',
        '"getChatFolderInviteLinks"',
        '"createChatFolderInviteLink"',
        '"reorderChatFolders"',
        '"checkChatFolderInviteLink"',
        '"addChatFolderByInviteLink"',
        '"mountain-lion"',
    ]:
        if fragment not in client_text:
            errors.append("%s: unified chat-folder TDLib contract is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        'assetName:@"folder-add"',
        'assetName:@"folder-remove"',
        'assetName:@"folder-share"',
        'assetName:@"upload"',
        "reorderChatFolderDefinitions:",
        "chatFolderInvitePreviewForLink:",
        "importChatFolderWithInviteLink:",
        "definitionHasInclusionRule:",
        "setObjectValue:",
        "shareLinkForChatFolderID:",
        "TGChatFolderListCell",
        "@interface TGChatFolderListCell : TGRepresentedObjectCell",
        "@interface TGChatFolderChatCell : TGRepresentedObjectCell",
        "[self representedObject]",
        "TGDrawAvatarInRect",
        'TGDrawTemplateIconAsset(@"folder"',
        "setReleasedWhenClosed:NO",
    ]:
        if fragment not in controller_text:
            errors.append("%s: chat-folder management UI is missing `%s`" %
                          (controller_rel, fragment))
    for fragment in [
        "showChatFolderManagementWindow:",
        "chatFolderManagementWindowControllerDidChangeFolders:",
        "reloadChatFiltersIfReady",
    ]:
        if fragment not in host_text:
            errors.append("%s: chat-folder host wiring is missing `%s`" %
                          (host_rel, fragment))
    for fragment in [
        "settingsFoldersCardView",
        "settingsFoldersSectionField",
        'TGLoc(@"settings.section.folders")',
        'setIconName:@"folder"',
    ]:
        if fragment not in status_text:
            errors.append("%s: dedicated settings folder section is missing `%s`" %
                          (status_rel, fragment))
    for fragment in [
        "foldersCardHeight",
        "[self.settingsChatFoldersButton setFrame:",
        "[self showView:self.settingsFoldersCardView visible:showSettings]",
    ]:
        if fragment not in layout_text:
            errors.append("%s: settings folder section layout is missing `%s`" %
                          (layout_rel, fragment))
    for icon_name in ["folder-add.png", "folder-remove.png", "folder-share.png"]:
        icon_path = os.path.join(ROOT, "Sources", "Resources", "Icons", icon_name)
        if not os.path.isfile(icon_path):
            errors.append("Sources/Resources/Icons/%s: required existing icon is missing" %
                          icon_name)


def check_qr_login_and_reaction_picker_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    qr_controller_rel = os.path.join("Sources", "UI", "TGQRCodeLoginWindowController.m")
    qr_generator_rel = os.path.join("Sources", "UI", "TGQRCodeImageGenerator.m")
    auth_rel = os.path.join("Sources", "UI", "TGStatusWindowController+AuthComposerState.inc")
    layout_rel = os.path.join("Sources", "UI", "TGStatusWindowController+SectionLayout.inc")
    contacts_rel = os.path.join("Sources", "UI", "TGContactsViewController.m")
    video_note_rel = os.path.join("Sources", "UI", "TGVideoNoteRecorderWindowController.m")
    menu_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    reaction_rel = os.path.join("Sources", "UI", "TGReactionMenuRowView.m")
    project_rel = "Telegraphica.xcodeproj/project.pbxproj"
    client_text = read_text(os.path.join(ROOT, client_rel))
    qr_controller_text = read_text(os.path.join(ROOT, qr_controller_rel))
    qr_generator_text = read_text(os.path.join(ROOT, qr_generator_rel))
    auth_text = read_text(os.path.join(ROOT, auth_rel))
    layout_text = read_text(os.path.join(ROOT, layout_rel))
    contacts_text = read_text(os.path.join(ROOT, contacts_rel))
    video_note_text = read_text(os.path.join(ROOT, video_note_rel))
    menu_text = read_text(os.path.join(ROOT, menu_rel))
    reaction_text = read_text(os.path.join(ROOT, reaction_rel))
    project_text = read_text(os.path.join(ROOT, project_rel))

    for fragment in [
        '"requestQrCodeAuthentication"',
        '"authorizationStateWaitOtherDeviceConfirmation"',
        "currentAuthenticationQRCodeLink",
        "cancelPendingQRCodeAuthenticationWithTimeout:",
        '"telegraphica-cancel-qr-auth"',
        'isEqualToString:@"updateAuthorizationState"',
        "shouldSeedAuthorizationCache",
    ]:
        if fragment not in client_text:
            errors.append("%s: QR authentication contract is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "TGQRCodeImageGenerator",
        "beginQRCodeAuthentication",
        "authorizationStateDidChange:",
        "maximumSide:300.0",
        "qrCodeLoginWindowControllerDidCancel:",
    ]:
        if fragment not in qr_controller_text:
            errors.append("%s: QR login window is missing `%s`" %
                          (qr_controller_rel, fragment))
    if "_closeButton" in qr_controller_text:
        errors.append("%s: redundant in-window QR close button must not be present" %
                      qr_controller_rel)
    for fragment in [
        "qrcodegen_encodeText",
        "qrcodegen_getModule",
        "quietZone = 4",
    ]:
        if fragment not in qr_generator_text:
            errors.append("%s: offline QR generator is missing `%s`" %
                          (qr_generator_rel, fragment))
    for fragment in [
        "openQRCodeLogin:",
        'isEqualToString:@"waitOtherDeviceConfirmation"',
        'TGLoc(@"login.or")',
        "qrCodeLoginWindowControllerDidCancel:",
        "recoverPhoneLoginFromPendingQRCodeState",
        "cancelPendingQRCodeAuthenticationWithTimeout:8.0",
        "shutdownWithTimeout:1.0",
        "qrPhoneLoginRecoveryVisible",
        "authorizationPresentationState",
    ]:
        if fragment not in auth_text:
            errors.append("%s: QR login host wiring is missing `%s`" %
                          (auth_rel, fragment))
    cancel_method_start = auth_text.find(
        "- (void)qrCodeLoginWindowControllerDidCancel:")
    cancel_method_end = auth_text.find(
        "- (BOOL)isTerminalAuthorizationState:", cancel_method_start)
    cancel_method = auth_text[cancel_method_start:cancel_method_end]
    explicit_cancel = cancel_method.find(
        "recoverPhoneLoginFromPendingQRCodeState")
    phone_recovery_presentation = cancel_method.find(
        "self.qrPhoneLoginRecoveryVisible = YES;")
    if cancel_method_start < 0 or explicit_cancel < 0 or phone_recovery_presentation < 0:
        errors.append("%s: QR cancellation recovery flow is incomplete" % auth_rel)
    client_cancel_start = client_text.find(
        "- (NSString *)cancelPendingQRCodeAuthenticationWithTimeout:")
    client_cancel_end = client_text.find(
        "- (NSDictionary *)currentUserProfileSummaryWithTimeout:",
        client_cancel_start)
    client_cancel_method = client_text[client_cancel_start:client_cancel_end]
    if (client_cancel_start < 0 or
            'setObject:@"logOut" forKey:@"@type"' not in client_cancel_method):
        errors.append(
            "%s: pending QR authentication must be canceled through TDLib "
            "before the client is replaced" % client_rel)
    for fragment in ["authorizationPresentationState"]:
        if fragment not in layout_text:
            errors.append("%s: QR phone recovery layout is missing `%s`" %
                          (layout_rel, fragment))
    for fragment in ["phoneLoginLayout", "qrButtonY", "qrButtonWidth"]:
        if fragment not in layout_text:
            errors.append("%s: QR/phone login layout is missing `%s`" %
                          (layout_rel, fragment))
    for fragment in ["authorizationRetryCount", 'TGLoc(@"contacts.authWaiting")']:
        if fragment not in contacts_text:
            errors.append("%s: post-authorization contact retry is missing `%s`" %
                          (contacts_rel, fragment))
    for fragment in ["previewClipLayer",
                     "setCornerRadius:180.0",
                     "[self.previewClipLayer addSublayer:self.cameraPreviewLayer]",
                     "TGThemeDrawGroupedCardInPath(backgroundPath"]:
        if fragment not in video_note_text:
            errors.append("%s: video-note opaque circular preview host is missing `%s`" %
                          (video_note_rel, fragment))
    if "[self.cameraPreviewLayer setMask:" in video_note_text:
        errors.append(
            "%s: AVCaptureVideoPreviewLayer must not be masked directly on "
            "legacy Core Animation" % video_note_rel)
    for source_name in [
        "TGQRCodeImageGenerator.m",
        "TGQRCodeLoginWindowController.m",
        "TGReactionMenuRowView.m",
        "qrcodegen.c",
    ]:
        if source_name not in project_text:
            errors.append("%s: target membership is missing `%s`" %
                          (project_rel, source_name))
    if "TGReactionMenuRowView" not in menu_text or "reactionGridView" not in menu_text:
        errors.append("%s: scrollable reaction grid is not wired into the message menu" %
                      menu_rel)
    for fragment in ["representedObject", "cancelTracking"]:
        if fragment not in reaction_text:
            errors.append("%s: reaction picker behavior is missing `%s`" %
                          (reaction_rel, fragment))
    qr_icon = os.path.join(ROOT, "Sources", "Resources", "Icons", "qr-scan.png")
    if not os.path.isfile(qr_icon):
        errors.append("Sources/Resources/Icons/qr-scan.png: user-provided QR icon is missing")


def check_forum_topic_management_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient+ForumTopics.m")
    host_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ForumTopicManagement.inc")
    flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+TableForumFlow.inc")
    menu_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    model_rel = os.path.join("Sources", "Core", "TGChatItem.h")
    project_rel = os.path.join("Telegraphica.xcodeproj", "project.pbxproj")
    client_text = read_text(os.path.join(ROOT, client_rel))
    host_text = read_text(os.path.join(ROOT, host_rel))
    flow_text = read_text(os.path.join(ROOT, flow_rel))
    menu_text = read_text(os.path.join(ROOT, menu_rel))
    model_text = read_text(os.path.join(ROOT, model_rel))
    project_text = read_text(os.path.join(ROOT, project_rel))

    for fragment in [
        '"createForumTopic"',
        '"editForumTopic"',
        '"toggleForumTopicIsClosed"',
        '"toggleForumTopicIsPinned"',
        '"deleteForumTopic"',
        '"forumTopicIcon"',
    ]:
        if fragment not in client_text:
            errors.append("%s: forum topic TDLib contract is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "createForumTopic:",
        "renameForumTopicFromMenu:",
        "toggleForumTopicClosedFromMenu:",
        "toggleForumTopicPinnedFromMenu:",
        "deleteForumTopicFromMenu:",
        "reloadCurrentForumTopicListInteractive:NO",
    ]:
        if fragment not in host_text:
            errors.append("%s: forum topic host action is missing `%s`" %
                          (host_rel, fragment))
    for fragment in [
        "[self.composeChatButton setAction:@selector(createForumTopic:)]",
        "[self.composeChatButton setAction:@selector(openNewChatWindow:)]",
    ]:
        if fragment not in flow_text:
            errors.append("%s: forum topic compose-button routing is missing `%s`" %
                          (flow_rel, fragment))
    if "populateForumTopicContextMenu:menu forItem:item" not in menu_text:
        errors.append("%s: forum topic context menu is not routed" % menu_rel)
    for fragment in ["forumTopicClosed", "forumTopicPinned"]:
        if fragment not in model_text:
            errors.append("%s: forum topic state is missing `%s`" % (model_rel, fragment))
    if "TGTDLibClient+ForumTopics.m in Sources" not in project_text:
        errors.append("%s: target membership is missing `TGTDLibClient+ForumTopics.m`" %
                      project_rel)


def check_server_reaction_catalog_contract(errors):
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient+Reactions.m")
    host_rel = os.path.join("Sources", "UI", "TGStatusWindowController+ReactionCatalog.inc")
    menu_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    row_rel = os.path.join("Sources", "UI", "TGReactionMenuRowView.m")
    project_rel = os.path.join("Telegraphica.xcodeproj", "project.pbxproj")
    client_text = read_text(os.path.join(ROOT, client_rel))
    host_text = read_text(os.path.join(ROOT, host_rel))
    menu_text = read_text(os.path.join(ROOT, menu_rel))
    row_text = read_text(os.path.join(ROOT, row_rel))
    project_text = read_text(os.path.join(ROOT, project_rel))

    for fragment in [
        '"getMessageAvailableReactions"',
        '"availableReactions"',
        '"top_reactions"',
        '"recent_reactions"',
        '"popular_reactions"',
        '"reactionTypeEmoji"',
    ]:
        if fragment not in client_text:
            errors.append("%s: server reaction catalog is missing `%s`" %
                          (client_rel, fragment))
    if "reactionTypePaid" in client_text or "allow_custom_emoji" in client_text:
        errors.append("%s: paid/custom reaction paths must not be exposed by the free reaction picker" %
                      client_rel)
    for fragment in [
        "prefetchReactionCatalogForMessageItem:",
        "availableReactionEmojisByChatID",
        "reactionCatalogAttemptedChatIDs",
        "fallbackStandardReactionEmojis",
        "TGReactionEmojiCanRender(emoji)",
        "must never displace these legacy-safe defaults",
        "Preserve unsupported server reactions at the end",
        "unsupportedCount < 8U",
    ]:
        if fragment not in host_text:
            errors.append("%s: reaction catalog cache is missing `%s`" %
                          (host_rel, fragment))
    if "reactionEmojisForMessageItem:item" not in menu_text:
        errors.append("%s: message menu does not use the reaction catalog" % menu_rel)
    for fragment in [
        "TGReactionEmojiCanRender",
        "legacySafeEmojis",
        "TGReactionMenuDocumentView",
        "setHasVerticalScroller:",
        "maximumVisibleRows",
        'displayEmoji =',
        '@"?"',
    ]:
        if fragment not in row_text:
            errors.append("%s: unsupported emoji fallback is missing `%s`" %
                          (row_rel, fragment))
    layout_rel = os.path.join("Sources", "UI", "TGMessageLayoutSupport.m")
    cells_rel = os.path.join("Sources", "UI", "TGStatusViewCells.m")
    layout_text = read_text(os.path.join(ROOT, layout_rel))
    cells_text = read_text(os.path.join(ROOT, cells_rel))
    for fragment in [
        "TGStringByReplacingUnrenderableEmoji",
        "TGReplaceUnrenderableEmojiInAttributedString",
        "rangeOfComposedCharacterSequenceAtIndex:",
        "NSNullGlyph",
        "legacySafeEmojis",
        'withString:@"?"',
    ]:
        if fragment not in layout_text:
            errors.append("%s: message emoji fallback is missing `%s`" %
                          (layout_rel, fragment))
    if "TGStringByReplacingUnrenderableEmoji([item reactionSummary]" not in cells_text:
        errors.append("%s: rendered reaction summaries do not use the legacy emoji fallback" %
                      cells_rel)
    if "TGTDLibClient+Reactions.m in Sources" not in project_text:
        errors.append("%s: target membership is missing `TGTDLibClient+Reactions.m`" %
                      project_rel)


def check_contact_birthday_contract(errors):
    core_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    profile_rel = os.path.join("Sources", "UI", "TGContactProfileView.m")
    host_rel = os.path.join("Sources", "UI", "TGStatusWindowController+BirthdayStatus.inc")
    flow_rel = os.path.join("Sources", "UI", "TGStatusWindowController+TableForumFlow.inc")
    core_text = read_text(os.path.join(ROOT, core_rel))
    profile_text = read_text(os.path.join(ROOT, profile_rel))
    host_text = read_text(os.path.join(ROOT, host_rel))
    flow_text = read_text(os.path.join(ROOT, flow_rel))
    for fragment in ['objectForKey:@"birthdate"', 'forKey:@"birthdate"']:
        if fragment not in core_text:
            errors.append("%s: contact birthday parsing is missing `%s`" %
                          (core_rel, fragment))
    for fragment in ["TGContactProfileBirthday", 'TGLoc(@"profile.birthday")']:
        if fragment not in profile_text:
            errors.append("%s: birthday profile row is missing `%s`" %
                          (profile_rel, fragment))
    for fragment in [
        "refreshSelectedChatBirthdayStatus",
        "TGBirthdateIsToday",
        'TGLoc(@"chat.birthdayToday")',
        "selectedChatBirthdayGeneration",
    ]:
        if fragment not in host_text:
            errors.append("%s: birthday chat banner is missing `%s`" %
                          (host_rel, fragment))
    if "[self refreshSelectedChatBirthdayStatus]" not in flow_text:
        errors.append("%s: chat selection does not refresh birthday status" % flow_rel)


def check_poll_management_contract(errors):
    header_rel = os.path.join("Sources", "Core", "TGTDLibClient.h")
    core_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    menu_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMenus.inc")
    header_text = read_text(os.path.join(ROOT, header_rel))
    core_text = read_text(os.path.join(ROOT, core_rel))
    menu_text = read_text(os.path.join(ROOT, menu_rel))
    if "stopPollForChatID:" not in header_text:
        errors.append("%s: stop-poll client API is missing" % header_rel)
    for fragment in ['@"stopPoll"', 'forKey:@"reply_markup"', 'extraPrefix:@"telegraphica-stop-poll"']:
        if fragment not in core_text:
            errors.append("%s: stop-poll TDLib request is missing `%s`" %
                          (core_rel, fragment))
    for fragment in [
        'TGLoc(@"message.poll.stop")',
        "@selector(stopPollFromMenu:)",
        "- (void)stopPollFromMenu:",
        "[item setPollClosed:YES]",
    ]:
        if fragment not in menu_text:
            errors.append("%s: poll close UI is missing `%s`" %
                          (menu_rel, fragment))


def check_received_link_preview_contract(errors):
    item_rel = os.path.join("Sources", "Core", "TGMessageItem.h")
    client_rel = os.path.join("Sources", "Core", "TGTDLibClient.m")
    layout_rel = os.path.join("Sources", "UI", "TGMessageLayoutSupport.m")
    cells_rel = os.path.join("Sources", "UI", "TGStatusViewCells.m")
    hit_rel = os.path.join("Sources", "UI", "TGStatusWindowController+MessageMediaHitTesting.inc")
    item_text = read_text(os.path.join(ROOT, item_rel))
    client_text = read_text(os.path.join(ROOT, client_rel))
    layout_text = read_text(os.path.join(ROOT, layout_rel))
    cells_text = read_text(os.path.join(ROOT, cells_rel))
    hit_text = read_text(os.path.join(ROOT, hit_rel))
    if "linkPreviewInfo" not in item_text:
        errors.append("%s: received link preview model is missing" % item_rel)
    for fragment in [
        'objectForKey:@"link_preview"',
        "linkPreviewInfoFromMessageContentObject:",
        '@"show_large_media"',
        '@"show_above_text"',
    ]:
        if fragment not in client_text:
            errors.append("%s: received link preview parsing is missing `%s`" %
                          (client_rel, fragment))
    for fragment in [
        "TGLinkPreviewCardHeightForItem",
        "TGLinkPreviewCardRectForItem",
        "TGDrawLinkPreviewCardForItem",
    ]:
        if fragment not in layout_text:
            errors.append("%s: link preview layout is missing `%s`" %
                          (layout_rel, fragment))
    if "TGDrawLinkPreviewCardForItem" not in cells_text:
        errors.append("%s: message cells do not draw received link previews" % cells_rel)
    for fragment in ["TGLinkPreviewCardRectForItem", 'objectForKey:@"url"', "openURL:url"]:
        if fragment not in hit_text:
            errors.append("%s: link preview card click handling is missing `%s`" %
                          (hit_rel, fragment))


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
    check_text_interaction_contract(errors)
    check_additional_message_types_contract(errors)
    check_call_transport_stability_contract(errors)
    check_media_file_management_contract(errors)
    check_primary_navigation_contract(errors)
    check_retro_console_contract(errors)
    check_chat_archive_contract(errors)
    check_chat_history_deletion_contract(errors)
    check_chat_navigation_actions_contract(errors)
    check_message_link_contract(errors)
    check_composer_link_editor_contract(errors)
    check_hourly_update_check_contract(errors)
    check_chat_folder_management_contract(errors)
    check_qr_login_and_reaction_picker_contract(errors)
    check_forum_topic_management_contract(errors)
    check_server_reaction_catalog_contract(errors)
    check_contact_birthday_contract(errors)
    check_poll_management_contract(errors)
    check_received_link_preview_contract(errors)
    if errors:
        print("Static project tests failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Static project tests passed: localization, project membership, test structure, local-data guard.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
