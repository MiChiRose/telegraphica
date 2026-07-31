#import "TGCallAudioEngine.h"

#import "../../ModernCallTransport/TGModernCallTransport.h"
#import "../Services/TGLogger.h"
#import "../Services/TGSystemCompatibility.h"
#import <dlfcn.h>

static NSString * const TGCallAudioEngineErrorDomain = @"TelegraphicaCallAudioEngine";

typedef int (*TGTransportABIVersionFunction)(void);
typedef const char *(*TGTransportVersionsFunction)(void);
typedef int (*TGTransportMaxLayerFunction)(void);
typedef void *(*TGTransportCreateFunction)(const char *,
                                           TGModernCallCallbacks,
                                           void *,
                                           char *,
                                           size_t);
typedef void (*TGTransportReceiveSignalingFunction)(void *, const uint8_t *, size_t);
typedef void (*TGTransportSetMutedFunction)(void *, int);
typedef int64_t (*TGTransportPreferredRelayFunction)(void *);
typedef void (*TGTransportStopFunction)(void *);

typedef struct TGModernTransportAPI {
    void *library;
    TGTransportABIVersionFunction abiVersion;
    TGTransportVersionsFunction versions;
    TGTransportMaxLayerFunction maxLayer;
    TGTransportCreateFunction create;
    TGTransportReceiveSignalingFunction receiveSignaling;
    TGTransportSetMutedFunction setMicrophoneMuted;
    TGTransportSetMutedFunction setSpeakerMuted;
    TGTransportSetMutedFunction setCameraEnabled;
    TGTransportPreferredRelayFunction preferredRelayID;
    TGTransportStopFunction stop;
} TGModernTransportAPI;

static TGModernTransportAPI TGLoadedTransportAPI;
static dispatch_once_t TGLoadedTransportOnce;

static NSString *TGModernTransportLibraryPath(void) {
    NSString *override = [[[NSProcessInfo processInfo] environment]
        objectForKey:@"TELEGRAPHICA_CALL_TRANSPORT_PATH"];
    if ([override length] > 0) {
        return [override stringByExpandingTildeInPath];
    }
    NSString *frameworks = [[NSBundle mainBundle] privateFrameworksPath];
    if (![frameworks length]) {
        frameworks = [[[NSBundle mainBundle] bundlePath]
            stringByAppendingPathComponent:@"Contents/Frameworks"];
    }
    return [frameworks stringByAppendingPathComponent:@"TelegraphicaCallTransport.dylib"];
}

static void *TGRequiredTransportSymbol(void *library, const char *name) {
    return library ? dlsym(library, name) : NULL;
}

static TGModernTransportAPI *TGModernTransport(void) {
    if (!TGSystemSupportsModernTelegramAudioCalls()) {
        return NULL;
    }
    dispatch_once(&TGLoadedTransportOnce, ^{
        NSString *path = TGModernTransportLibraryPath();
        void *library = dlopen([path fileSystemRepresentation], RTLD_NOW | RTLD_LOCAL);
        if (!library) {
            const char *loadError = dlerror();
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:
                @"Audio call: modern transport not loaded from %@ (%s).",
                path,
                loadError ? loadError : "unknown error"]];
            return;
        }
        TGLoadedTransportAPI.library = library;
        TGLoadedTransportAPI.abiVersion = (TGTransportABIVersionFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportABIVersion");
        TGLoadedTransportAPI.versions = (TGTransportVersionsFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportVersions");
        TGLoadedTransportAPI.maxLayer = (TGTransportMaxLayerFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportMaxLayer");
        TGLoadedTransportAPI.create = (TGTransportCreateFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportCreate");
        TGLoadedTransportAPI.receiveSignaling = (TGTransportReceiveSignalingFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportReceiveSignalingData");
        TGLoadedTransportAPI.setMicrophoneMuted = (TGTransportSetMutedFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportSetMicrophoneMuted");
        TGLoadedTransportAPI.setSpeakerMuted = (TGTransportSetMutedFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportSetSpeakerMuted");
        TGLoadedTransportAPI.setCameraEnabled = (TGTransportSetMutedFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportSetCameraEnabled");
        TGLoadedTransportAPI.preferredRelayID = (TGTransportPreferredRelayFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportPreferredRelayID");
        TGLoadedTransportAPI.stop = (TGTransportStopFunction)
            TGRequiredTransportSymbol(library, "TGModernCallTransportStop");
        if (!TGLoadedTransportAPI.abiVersion ||
            !TGLoadedTransportAPI.versions ||
            !TGLoadedTransportAPI.maxLayer ||
            !TGLoadedTransportAPI.create ||
            !TGLoadedTransportAPI.receiveSignaling ||
            !TGLoadedTransportAPI.setMicrophoneMuted ||
            !TGLoadedTransportAPI.setSpeakerMuted ||
            !TGLoadedTransportAPI.setCameraEnabled ||
            !TGLoadedTransportAPI.preferredRelayID ||
            !TGLoadedTransportAPI.stop ||
            TGLoadedTransportAPI.abiVersion() != TG_MODERN_CALL_TRANSPORT_ABI_VERSION) {
            [[TGLogger sharedLogger] log:@"Audio call: modern transport ABI is incomplete or incompatible."];
            dlclose(library);
            memset(&TGLoadedTransportAPI, 0, sizeof(TGLoadedTransportAPI));
            return;
        }
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:
            @"Audio call: modern transport loaded for protocols %s (max layer %d).",
            TGLoadedTransportAPI.versions(),
            TGLoadedTransportAPI.maxLayer()]];
    });
    return TGLoadedTransportAPI.library ? &TGLoadedTransportAPI : NULL;
}

@interface TGCallAudioEngine ()
- (void)deliverStateNumber:(NSNumber *)stateNumber;
- (void)deliverSignalBarsNumber:(NSNumber *)signalBarsNumber;
- (void)deliverSignalingData:(NSData *)data;
- (void)deliverTransportLog:(NSString *)message;
- (void)deliverVideoFramePayload:(NSDictionary *)payload;
- (void)deliverRemoteVideoStateNumber:(NSNumber *)stateNumber;
@end

static void TGModernStateChanged(void *context, int state) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    [engine performSelectorOnMainThread:@selector(deliverStateNumber:)
                            withObject:[NSNumber numberWithInt:state]
                         waitUntilDone:NO];
    [pool drain];
}

static void TGModernSignalBarsChanged(void *context, int bars) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    [engine performSelectorOnMainThread:@selector(deliverSignalBarsNumber:)
                            withObject:[NSNumber numberWithInteger:MAX(0, bars)]
                         waitUntilDone:NO];
    [pool drain];
}

static void TGModernSignalingDataEmitted(void *context, const uint8_t *bytes, size_t length) {
    if (!bytes || length == 0) {
        return;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    NSData *data = [NSData dataWithBytes:bytes length:length];
    [engine performSelectorOnMainThread:@selector(deliverSignalingData:)
                            withObject:data
                         waitUntilDone:NO];
    [pool drain];
}

static void TGModernTransportLog(void *context, const char *message) {
    if (!message) {
        return;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    NSString *text = [NSString stringWithUTF8String:message];
    [engine performSelectorOnMainThread:@selector(deliverTransportLog:)
                            withObject:text
                         waitUntilDone:NO];
    [pool drain];
}

static void TGModernVideoFrame(void *context,
                               int local,
                               const uint8_t *bytes,
                               size_t length,
                               int width,
                               int height,
                               int bytesPerRow) {
    if (!bytes || length == 0 || width <= 0 || height <= 0 || bytesPerRow <= 0) {
        return;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSData dataWithBytes:bytes length:length], @"data",
                             [NSNumber numberWithInt:width], @"width",
                             [NSNumber numberWithInt:height], @"height",
                             [NSNumber numberWithInt:bytesPerRow], @"bytes_per_row",
                             [NSNumber numberWithBool:(local != 0)], @"local",
                             nil];
    [engine performSelectorOnMainThread:@selector(deliverVideoFramePayload:)
                            withObject:payload
                         waitUntilDone:NO];
    [pool drain];
}

static void TGModernRemoteVideoStateChanged(void *context, int state) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGCallAudioEngine *engine = (TGCallAudioEngine *)context;
    [engine performSelectorOnMainThread:@selector(deliverRemoteVideoStateNumber:)
                            withObject:[NSNumber numberWithInt:state]
                         waitUntilDone:NO];
    [pool drain];
}

@implementation TGCallAudioEngine

@synthesize delegate = _delegate;

+ (BOOL)isOperatingSystemSupported {
    return TGSystemSupportsModernTelegramAudioCalls();
}

+ (BOOL)isTransportAvailable {
    return TGModernTransport() != NULL;
}

+ (NSString *)transportVersion {
    TGModernTransportAPI *api = TGModernTransport();
    return (api && api->versions()) ? [NSString stringWithUTF8String:api->versions()] : @"";
}

+ (NSArray *)protocolVersions {
    NSString *versions = [self transportVersion];
    if (![versions length]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *value in [versions componentsSeparatedByString:@","]) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed length]) {
            [result addObject:trimmed];
        }
    }
    return result;
}

+ (NSInteger)maximumProtocolLayer {
    TGModernTransportAPI *api = TGModernTransport();
    return api ? api->maxLayer() : 0;
}

- (BOOL)isRunning {
    return _running;
}

- (NSNumber *)preferredRelayID {
    return _preferredRelayID;
}

- (BOOL)startWithCall:(NSDictionary *)call error:(NSError **)error {
    if (_running || _transport) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:2
                                    userInfo:[NSDictionary dictionaryWithObject:
                                        @"An audio call is already active."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    TGModernTransportAPI *api = TGModernTransport();
    if (!api) {
        if (error) {
            NSString *message = [TGCallAudioEngine isOperatingSystemSupported]
                ? @"The modern Telegram audio-call transport is not bundled in this build."
                : @"Audio calls require OS X 10.9 or newer.";
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:1
                                    userInfo:[NSDictionary dictionaryWithObject:message
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    NSError *serializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:call
                                                       options:0
                                                         error:&serializationError];
    if (!jsonData) {
        if (error) {
            *error = serializationError;
        }
        return NO;
    }
    NSString *json = [[[NSString alloc] initWithData:jsonData
                                            encoding:NSUTF8StringEncoding] autorelease];
    char transportError[512] = { 0 };
    TGModernCallCallbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.stateChanged = &TGModernStateChanged;
    callbacks.signalBarsChanged = &TGModernSignalBarsChanged;
    callbacks.signalingDataEmitted = &TGModernSignalingDataEmitted;
    callbacks.logMessage = &TGModernTransportLog;
    callbacks.videoFrame = &TGModernVideoFrame;
    callbacks.remoteVideoStateChanged = &TGModernRemoteVideoStateChanged;
    _transport = api->create([json UTF8String],
                             callbacks,
                             self,
                             transportError,
                             sizeof(transportError));
    if (!_transport) {
        if (error) {
            NSString *message = transportError[0]
                ? [NSString stringWithUTF8String:transportError]
                : @"The modern Telegram audio engine could not be created.";
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:3
                                    userInfo:[NSDictionary dictionaryWithObject:message
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    _running = YES;
    [self deliverStateNumber:[NSNumber numberWithInteger:TGCallAudioEngineStateConnecting]];
    return YES;
}

- (void)receiveSignalingData:(NSData *)data {
    TGModernTransportAPI *api = TGModernTransport();
    if (api && _transport && [data length]) {
        api->receiveSignaling(_transport, (const uint8_t *)[data bytes], [data length]);
    }
}

- (void)setMicrophoneMuted:(BOOL)muted {
    TGModernTransportAPI *api = TGModernTransport();
    if (api && _transport) {
        api->setMicrophoneMuted(_transport, muted ? 1 : 0);
    }
}

- (void)setSpeakerMuted:(BOOL)muted {
    TGModernTransportAPI *api = TGModernTransport();
    if (api && _transport) {
        api->setSpeakerMuted(_transport, muted ? 1 : 0);
    }
}

- (void)setCameraEnabled:(BOOL)enabled {
    TGModernTransportAPI *api = TGModernTransport();
    if (api && _transport) {
        api->setCameraEnabled(_transport, enabled ? 1 : 0);
    }
}

- (void)stop {
    TGModernTransportAPI *api = TGModernTransport();
    if (api && _transport) {
        int64_t relayID = api->preferredRelayID(_transport);
        [_preferredRelayID release];
        _preferredRelayID = [[NSNumber alloc] initWithLongLong:relayID];
        api->stop(_transport);
        _transport = NULL;
    }
    if (_running) {
        _running = NO;
        [self deliverStateNumber:[NSNumber numberWithInteger:TGCallAudioEngineStateStopped]];
    }
}

- (void)deliverStateNumber:(NSNumber *)stateNumber {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didChangeState:)]) {
        [delegate callAudioEngine:self
                  didChangeState:(TGCallAudioEngineState)[stateNumber integerValue]];
    }
}

- (void)deliverSignalBarsNumber:(NSNumber *)signalBarsNumber {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didChangeSignalBars:)]) {
        [delegate callAudioEngine:self
             didChangeSignalBars:[signalBarsNumber unsignedIntegerValue]];
    }
}

- (void)deliverSignalingData:(NSData *)data {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didEmitSignalingData:)]) {
        [delegate callAudioEngine:self didEmitSignalingData:data];
    }
}

- (void)deliverTransportLog:(NSString *)message {
    if ([message length]) {
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Audio call: %@",
                                      message]];
    }
}

- (void)deliverVideoFramePayload:(NSDictionary *)payload {
    NSData *data = [payload objectForKey:@"data"];
    NSInteger width = [[payload objectForKey:@"width"] integerValue];
    NSInteger height = [[payload objectForKey:@"height"] integerValue];
    NSInteger bytesPerRow = [[payload objectForKey:@"bytes_per_row"] integerValue];
    if (![data length] || width <= 0 || height <= 0 || bytesPerRow < width * 4) {
        return;
    }
    NSBitmapImageRep *representation =
        [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                pixelsWide:width
                                                pixelsHigh:height
                                             bitsPerSample:8
                                           samplesPerPixel:4
                                                  hasAlpha:YES
                                                  isPlanar:NO
                                            colorSpaceName:NSDeviceRGBColorSpace
                                               bitmapFormat:(NSAlphaFirstBitmapFormat |
                                                             NSAlphaNonpremultipliedBitmapFormat)
                                                bytesPerRow:bytesPerRow
                                               bitsPerPixel:32] autorelease];
    if (!representation) {
        return;
    }
    memcpy([representation bitmapData],
           [data bytes],
           MIN((NSUInteger)(bytesPerRow * height), [data length]));
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [image addRepresentation:representation];
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didReceiveVideoImage:local:)]) {
        [delegate callAudioEngine:self
             didReceiveVideoImage:image
                            local:[[payload objectForKey:@"local"] boolValue]];
    }
}

- (void)deliverRemoteVideoStateNumber:(NSNumber *)stateNumber {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didChangeRemoteVideoState:)]) {
        [delegate callAudioEngine:self
          didChangeRemoteVideoState:[stateNumber integerValue]];
    }
}

- (void)dealloc {
    [self stop];
    [_preferredRelayID release];
    [super dealloc];
}

@end
