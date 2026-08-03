#import <Foundation/Foundation.h>
#import "TGTDLibCapabilities.h"

static int TGCapabilityProbeFailures = 0;

static void TGCapabilityAssert(BOOL condition, NSString *message) {
    if (!condition) {
        TGCapabilityProbeFailures++;
        fprintf(stderr, "tdlib_capabilities_probe: %s\n", [[message description] UTF8String]);
    }
}

static NSDictionary *TGCapabilityError(NSInteger code, NSString *message) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"error", @"@type",
            [NSNumber numberWithInteger:code], @"code",
            message, @"message",
            nil];
}

static void TGTestLaneAndMetadata(void) {
    TGTDLibCapabilities *fallback = [[[TGTDLibCapabilities alloc]
        initWithLoadedLibraryPath:@"/Applications/Telegraphica.app/Contents/Frameworks/libtdjson-mountain-lion.dylib"] autorelease];
    TGCapabilityAssert([fallback lane] == TGTDLibLaneMountainLionFallback,
                       @"mountain-lion dylib should select the fallback lane");

    TGTDLibCapabilities *mainLane = [[[TGTDLibCapabilities alloc]
        initWithLoadedLibraryPath:@"/Applications/Telegraphica.app/Contents/Frameworks/libtdjson.dylib"] autorelease];
    TGCapabilityAssert([mainLane lane] == TGTDLibLaneMavericksOrNewer,
                       @"ordinary tdjson dylib should select the Mavericks+ lane");
    [mainLane recordTDLibVersion:@"1.8.65"
                         commit:@"abc123"
                   mtprotoLayer:[NSNumber numberWithInteger:201]
                    buildStatus:@"verified"];
    TGCapabilityAssert([[mainLane tdlibVersion] isEqualToString:@"1.8.65"], @"TDLib version should be cached");
    TGCapabilityAssert([[mainLane tdlibCommit] isEqualToString:@"abc123"], @"TDLib commit should be cached");
    TGCapabilityAssert([[mainLane mtprotoLayer] integerValue] == 201, @"MTProto layer should be cached");
    TGCapabilityAssert([[mainLane buildStatus] isEqualToString:@"verified"], @"build status should be cached");
}

static void TGTestProbeClassification(void) {
    TGTDLibCapabilities *capabilities = [[[TGTDLibCapabilities alloc] initWithLoadedLibraryPath:@"libtdjson.dylib"] autorelease];
    NSDictionary *success = [NSDictionary dictionaryWithObject:@"ok" forKey:@"@type"];
    [capabilities recordProbeResponse:success error:nil
                         forCapability:TGTDLibCapabilitySharedChatFolders source:@"fixture.success"];
    TGCapabilityAssert([capabilities supportsCapability:TGTDLibCapabilitySharedChatFolders],
                       @"successful response should mark support as known and supported");
    TGCapabilityAssert([capabilities lastProbeStateForCapability:TGTDLibCapabilitySharedChatFolders] == TGTDLibCapabilityStateSupported,
                       @"successful response should record a supported outcome");

    [capabilities recordProbeResponse:TGCapabilityError(400, @"Unknown request: createChatFolderInviteLink")
                                 error:nil
                         forCapability:TGTDLibCapabilitySharedChatFolders source:@"fixture.unsupported"];
    TGCapabilityAssert([capabilities supportStateForCapability:TGTDLibCapabilitySharedChatFolders] == TGTDLibCapabilityStateUnsupported,
                       @"unknown request should mark the TDLib feature unsupported");

    [capabilities recordProbeResponse:success error:nil
                         forCapability:TGTDLibCapabilityForumTopics source:@"fixture.success"];
    [capabilities recordProbeResponse:TGCapabilityError(403, @"CHAT_ADMIN_REQUIRED")
                                 error:nil
                         forCapability:TGTDLibCapabilityForumTopics source:@"fixture.forbidden"];
    TGCapabilityAssert([capabilities supportsCapability:TGTDLibCapabilityForumTopics],
                       @"chat permission failure must not globally disable a supported feature");
    TGCapabilityAssert([capabilities lastProbeStateForCapability:TGTDLibCapabilityForumTopics] == TGTDLibCapabilityStateForbidden,
                       @"chat permission failure should remain visible as forbidden");

    [capabilities recordProbeResponse:TGCapabilityError(500, @"Temporary network connection failure")
                                 error:nil
                         forCapability:TGTDLibCapabilityStoriesViewer source:@"fixture.temporary"];
    TGCapabilityAssert([capabilities supportStateForCapability:TGTDLibCapabilityStoriesViewer] == TGTDLibCapabilityStateUnknown,
                       @"temporary failure must not claim the feature is unsupported");
    TGCapabilityAssert([capabilities lastProbeStateForCapability:TGTDLibCapabilityStoriesViewer] == TGTDLibCapabilityStateTemporarilyUnavailable,
                       @"temporary failure should have its own state");
    TGCapabilityAssert([capabilities hasCachedProbeForCapability:TGTDLibCapabilityStoriesViewer],
                       @"temporary result should be cached for synchronous UI reads");
    TGCapabilityAssert([[capabilities reasonForCapability:TGTDLibCapabilityStoriesViewer]
                        rangeOfString:@"network" options:NSCaseInsensitiveSearch].location != NSNotFound,
                       @"UI-facing reason should retain the bounded probe explanation");
}

static void TGTestRequestMappingAndSnapshot(void) {
    TGCapabilityAssert([[TGTDLibCapabilities capabilityIdentifierForRequestType:@"requestQrCodeAuthentication"]
                        isEqualToString:TGTDLibCapabilityQRCodeAuthentication],
                       @"QR request should map to the QR capability");
    TGCapabilityAssert([[TGTDLibCapabilities capabilityIdentifierForRequestType:@"createForumTopic"]
                        isEqualToString:TGTDLibCapabilityForumTopics],
                       @"forum request should map to the forum capability");
    TGCapabilityAssert([TGTDLibCapabilities capabilityIdentifierForRequestType:@"getMe"] == nil,
                       @"unrelated requests should not mutate feature capabilities");

    TGTDLibCapabilities *capabilities = [[[TGTDLibCapabilities alloc] initWithLoadedLibraryPath:nil] autorelease];
    NSDictionary *snapshot = [capabilities snapshot];
    TGCapabilityAssert([snapshot count] == [[TGTDLibCapabilities knownCapabilityIdentifiers] count],
                       @"snapshot should contain every declared capability");
    TGCapabilityAssert([[capabilities diagnosticSummary] rangeOfString:@"lane=unknown"].location != NSNotFound,
                       @"diagnostic summary should expose a safe lane value");
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGTestLaneAndMetadata();
    TGTestProbeClassification();
    TGTestRequestMappingAndSnapshot();
    if (TGCapabilityProbeFailures == 0) {
        printf("TDLib capability registry probe passed.\n");
    }
    [pool drain];
    return TGCapabilityProbeFailures == 0 ? 0 : 1;
}
