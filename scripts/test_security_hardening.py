#!/usr/bin/env python
from __future__ import print_function

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))


def read_text(relative_path):
    path = os.path.join(ROOT, relative_path)
    with open(path, "rb") as handle:
        data = handle.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def require(errors, relative_path, fragments):
    text = read_text(relative_path)
    for fragment in fragments:
        if fragment not in text:
            errors.append("%s: missing security contract `%s`" % (relative_path, fragment))
    return text


def require_before(errors, relative_path, earlier, later):
    text = read_text(relative_path)
    earlier_index = text.find(earlier)
    later_index = text.find(later)
    if earlier_index < 0 or later_index < 0 or earlier_index >= later_index:
        errors.append("%s: `%s` must guard `%s`" % (relative_path, earlier, later))


def method_body(text, signature, next_signature):
    start = text.find(signature)
    if start < 0:
        return ""
    end = text.find(next_signature, start + len(signature))
    return text[start:] if end < 0 else text[start:end]


def main():
    errors = []

    require(errors, "Sources/Core/TGTDLibClient.m", [
        'isEqualToString:@"messageVoiceNote"',
        'objectForKey:@"voice_note"',
        'isEqualToString:@"messageAudio"',
        'objectForKey:@"audio"',
        'isEqualToString:@"messageVideoNote"',
        'objectForKey:@"video_note"',
        "TGResourcePolicyAllowsAutoDownloadForMessageContent",
    ])
    require(errors, "Sources/Services/TGResourcePolicy.m", [
        "TGResourcePolicyAutoDownloadTypeForMessageContent",
        "declaredBytes <= 0",
        "return NO;",
        "declaredBytes <= maximumBytes",
    ])

    require(errors, "Sources/Media/TGWebPDecoder.m", [
        "TGMediaDimensionsFitDecodedBudget",
        "WebPDecodeRGBA",
    ])
    require_before(errors, "Sources/Media/TGWebPDecoder.m",
                   "TGMediaDimensionsFitDecodedBudget", "WebPDecodeRGBA")

    require(errors, "Sources/Media/TGInlineMediaPlaybackCoordinator.m", [
        "CGImageSourceGetCount",
        "TGMediaMaximumAnimatedFrameCount",
        "TGMediaDimensionsFitDecodedBudget",
        "[view invalidate]",
    ])
    require_before(errors, "Sources/Media/TGInlineMediaPlaybackCoordinator.m",
                   "TGInlineMediaGIFIsWithinBudget", "initWithContentsOfFile:mediaPath")

    require(errors, "Sources/Media/TGWebMAnimationView.mm", [
        "TGMediaMaximumCompressedWebMFrameBytes",
        "frame.len > (unsigned long long)UINT_MAX",
        "_decodeCancelled",
        "[_decodeOperation cancel]",
        "- (void)invalidate",
    ])
    require_before(errors, "Sources/Media/TGWebMAnimationView.mm",
                   "TGMediaMaximumCompressedWebMFrameBytes", "malloc((size_t)frame.len)")

    require(errors, "Sources/Media/TGTGSAnimationView.m", [
        "_invalidated",
        "[_renderOperation cancel]",
        "- (void)invalidate",
    ])
    require(errors, "Sources/Media/TGTGSFileValidator.m", [
        "TGMediaMaximumTGSRepeaterCopies",
        "TGTGSRepeatersAreSafe",
        "TGTGSMaximumJSONTraversalDepth",
    ])

    require(errors, "Sources/Media/TGOpusVoiceTranscoder.m", [
        "TGMediaMaximumOpusInputBytes",
        "TGMediaMaximumDecodedVoiceBytes",
        "TGMediaMaximumVoiceTranscodeSeconds",
        "TGOpusVoiceTranscodeCancellationToken",
        "setMaxConcurrentOperationCount:1",
        "[cancellationToken isCancelled]",
        "setStandardError:errorHandle",
    ])
    require(errors, "Tools/tgopusdec.c", [
        "TG_MAX_DECODED_WAV_BYTES",
        "maximum_frames - total_frames",
        "remove(output_path)",
    ])
    media_windows = require(errors, "Sources/UI/TGStatusWindowController+MediaWindows.inc", [
        "prepareOpusVoicePlaybackInBackground:",
        "cancelMediaPlaybackPreparation",
        "NSInvocationOperation",
        "addOperation:operation",
        "finishOpusVoicePlayback:",
    ])
    if "TGPlayableVoicePathByTranscodingIfNeeded" in method_body(
            media_windows,
            "- (BOOL)openPlayableMediaAtPath:",
            "- (void)prepareOpusVoicePlaybackInBackground:"):
        errors.append("Sources/UI/TGStatusWindowController+MediaWindows.inc: synchronous player entry point still transcodes Opus")

    notifications = require(errors, "Sources/UI/TGStatusWindowController+Notifications.inc", [
        "fetchNotificationChatInfoInBackground:",
        "performSelectorInBackground:@selector(fetchNotificationChatInfoInBackground:)",
        "fetch_pending",
        "fetch_complete",
        "fetch_retry_after",
    ])
    notification_lookup = method_body(
        notifications,
        "- (NSDictionary *)notificationChatInfoForChatID:",
        "- (NSString *)chatMuteDefaultsKeyForChatID:")
    if "chatSummaryForChatID:chatID" in notification_lookup:
        errors.append("Sources/UI/TGStatusWindowController+Notifications.inc: notification lookup still blocks on TDLib")

    vp9 = require(errors, "Vendor/libvpx/vp9/decoder/vp9_decodeframe.c", [
        "idx < 0 || idx >= FRAME_BUFFERS",
        "TG_VP9_MAX_DECODE_DIMENSION",
        "TG_VP9_MAX_DECODE_PIXELS",
    ])
    reference_anchor = vp9.find("const int idx = cm->ref_frame_map[ref]")
    reference_guard = vp9.find("idx < 0 || idx >= FRAME_BUFFERS", reference_anchor)
    reference_sink = vp9.find("frame_bufs[idx]", reference_guard)
    if reference_anchor < 0 or reference_guard < 0 or reference_sink < 0:
        errors.append("Vendor/libvpx/vp9/decoder/vp9_decodeframe.c: VP9 reference index must be validated immediately before frame_bufs access")

    require(errors, "Vendor/libwebp/src/dec/vp8l_dec.c", [
        "TG_MAX_HUFFMAN_TREE_GROUPS",
        "num_htree_groups > TG_MAX_HUFFMAN_TREE_GROUPS",
        "table_size > INT_MAX / num_htree_groups",
    ])

    require(errors, "Vendor/rlottie/src/lottie/lottieparser.cpp", [
        "TGMaximumRepeaterCopies",
        "std::isfinite(maxCopy)",
    ])
    require(errors, "Vendor/rlottie/src/lottie/lottieitem.cpp", [
        "TGMaximumRepeaterCopies",
        "std::isfinite(maximumCopies)",
        "copies >= static_cast<float>(mCopies)",
    ])

    if errors:
        print("Security hardening tests failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Security hardening contract checks passed; behavioral policy and queue checks run in the core logic probe.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
