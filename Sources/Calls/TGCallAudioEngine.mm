#import "TGCallAudioEngine.h"

#import "../Services/TGBase64Compatibility.h"
#import "../Services/TGLogger.h"

#ifndef TELEGRAPHICA_HAS_TGVOIP
#define TELEGRAPHICA_HAS_TGVOIP 0
#endif

#if TELEGRAPHICA_HAS_TGVOIP
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#include "TgVoip.h"
#include <algorithm>
#include <cstring>
#include <memory>
#include <vector>
#endif

static NSString * const TGCallAudioEngineErrorDomain = @"TelegraphicaCallAudioEngine";

static NSString *TGCallTransportLogPath(void) {
    if (![TGLogger diagnosticsEnabled]) {
        return nil;
    }
    NSArray *supportDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                      NSUserDomainMask,
                                                                      YES);
    NSString *supportDirectory = [supportDirectories count] > 0
        ? [supportDirectories objectAtIndex:0] : nil;
    if (![supportDirectory length]) {
        return nil;
    }
    NSString *logsDirectory = [[supportDirectory stringByAppendingPathComponent:@"Telegraphica"]
        stringByAppendingPathComponent:@"Logs"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:logsDirectory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL]) {
        return nil;
    }
    NSString *logPath = [logsDirectory stringByAppendingPathComponent:@"libtgvoip-current.log"];
    [fileManager removeItemAtPath:logPath error:NULL];
    return logPath;
}

@interface TGCallAudioEngine ()
- (void)deliverStateNumber:(NSNumber *)stateNumber;
- (void)deliverSignalBarsNumber:(NSNumber *)signalBarsNumber;
@end

#if TELEGRAPHICA_HAS_TGVOIP
static void TGCallRandomBytes(uint8_t *buffer, size_t length) {
    if (SecRandomCopyBytes(kSecRandomDefault, length, buffer) != errSecSuccess) {
        arc4random_buf(buffer, length);
    }
}

static void TGCallSHA1(uint8_t *message, size_t length, uint8_t *output) {
    CC_SHA1(message, (CC_LONG)length, output);
}

static void TGCallSHA256(uint8_t *message, size_t length, uint8_t *output) {
    CC_SHA256(message, (CC_LONG)length, output);
}

static BOOL TGCallAESBlock(const uint8_t *input, uint8_t *output, const uint8_t *key, CCOperation operation) {
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(operation,
                                    kCCAlgorithmAES128,
                                    kCCOptionECBMode,
                                    key,
                                    kCCKeySizeAES256,
                                    NULL,
                                    input,
                                    kCCBlockSizeAES128,
                                    output,
                                    kCCBlockSizeAES128,
                                    &moved);
    return status == kCCSuccess && moved == kCCBlockSizeAES128;
}

static void TGCallAESIGEEncrypt(uint8_t *input,
                               uint8_t *output,
                               size_t length,
                               uint8_t *key,
                               uint8_t *iv) {
    uint8_t previousCipher[kCCBlockSizeAES128];
    uint8_t previousPlain[kCCBlockSizeAES128];
    memcpy(previousCipher, iv, kCCBlockSizeAES128);
    memcpy(previousPlain, iv + kCCBlockSizeAES128, kCCBlockSizeAES128);
    size_t offset = 0;
    for (offset = 0; offset + kCCBlockSizeAES128 <= length; offset += kCCBlockSizeAES128) {
        uint8_t mixed[kCCBlockSizeAES128];
        uint8_t encrypted[kCCBlockSizeAES128];
        size_t index = 0;
        for (index = 0; index < kCCBlockSizeAES128; index++) {
            mixed[index] = input[offset + index] ^ previousCipher[index];
        }
        if (!TGCallAESBlock(mixed, encrypted, key, kCCEncrypt)) {
            memset(output + offset, 0, kCCBlockSizeAES128);
            continue;
        }
        for (index = 0; index < kCCBlockSizeAES128; index++) {
            output[offset + index] = encrypted[index] ^ previousPlain[index];
        }
        memcpy(previousCipher, output + offset, kCCBlockSizeAES128);
        memcpy(previousPlain, input + offset, kCCBlockSizeAES128);
    }
    memcpy(iv, previousCipher, kCCBlockSizeAES128);
    memcpy(iv + kCCBlockSizeAES128, previousPlain, kCCBlockSizeAES128);
}

static void TGCallAESIGEDecrypt(uint8_t *input,
                               uint8_t *output,
                               size_t length,
                               uint8_t *key,
                               uint8_t *iv) {
    uint8_t previousPlain[kCCBlockSizeAES128];
    uint8_t previousCipher[kCCBlockSizeAES128];
    memcpy(previousPlain, iv, kCCBlockSizeAES128);
    memcpy(previousCipher, iv + kCCBlockSizeAES128, kCCBlockSizeAES128);
    size_t offset = 0;
    for (offset = 0; offset + kCCBlockSizeAES128 <= length; offset += kCCBlockSizeAES128) {
        uint8_t mixed[kCCBlockSizeAES128];
        uint8_t decrypted[kCCBlockSizeAES128];
        size_t index = 0;
        for (index = 0; index < kCCBlockSizeAES128; index++) {
            mixed[index] = input[offset + index] ^ previousCipher[index];
        }
        if (!TGCallAESBlock(mixed, decrypted, key, kCCDecrypt)) {
            memset(output + offset, 0, kCCBlockSizeAES128);
            continue;
        }
        for (index = 0; index < kCCBlockSizeAES128; index++) {
            output[offset + index] = decrypted[index] ^ previousPlain[index];
        }
        memcpy(previousPlain, input + offset, kCCBlockSizeAES128);
        memcpy(previousCipher, output + offset, kCCBlockSizeAES128);
    }
    memcpy(iv, previousPlain, kCCBlockSizeAES128);
    memcpy(iv + kCCBlockSizeAES128, previousCipher, kCCBlockSizeAES128);
}

static void TGCallIncrementCounter(uint8_t *counter) {
    NSInteger index = kCCBlockSizeAES128 - 1;
    for (; index >= 0; index--) {
        counter[index]++;
        if (counter[index] != 0) {
            break;
        }
    }
}

static void TGCallAESCTREncrypt(uint8_t *inputOutput,
                               size_t length,
                               uint8_t *key,
                               uint8_t *iv,
                               uint8_t *encryptedCounter,
                               uint32_t *counterOffset) {
    uint32_t offset = *counterOffset;
    size_t index = 0;
    for (index = 0; index < length; index++) {
        if (offset == 0) {
            if (!TGCallAESBlock(iv, encryptedCounter, key, kCCEncrypt)) {
                memset(encryptedCounter, 0, kCCBlockSizeAES128);
            }
            TGCallIncrementCounter(iv);
        }
        inputOutput[index] ^= encryptedCounter[offset];
        offset = (offset + 1) % kCCBlockSizeAES128;
    }
    *counterOffset = offset;
}

static TgVoipEndpointType TGEndpointTypeForServer(NSDictionary *server) {
    NSDictionary *type = [[server objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [server objectForKey:@"type"] : nil;
    NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [type objectForKey:@"@type"] : @"";
    return [typeName isEqualToString:@"callServerTypeTelegramReflector"]
        ? TgVoipEndpointType::UdpRelay : TgVoipEndpointType::Inet;
}
#endif

@implementation TGCallAudioEngine

@synthesize delegate = _delegate;

+ (BOOL)isTransportAvailable {
#if TELEGRAPHICA_HAS_TGVOIP
    return YES;
#else
    return NO;
#endif
}

+ (NSString *)transportVersion {
#if TELEGRAPHICA_HAS_TGVOIP
    return [NSString stringWithUTF8String:TgVoip::getVersion().c_str()];
#else
    return @"";
#endif
}

- (BOOL)isRunning {
    return _running;
}

- (NSNumber *)preferredRelayID {
    return _preferredRelayID;
}

- (BOOL)startWithCall:(NSDictionary *)call error:(NSError **)error {
#if !TELEGRAPHICA_HAS_TGVOIP
    if (error) {
        *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                    code:1
                                userInfo:[NSDictionary dictionaryWithObject:@"Audio-call transport is not bundled in this build."
                                                                     forKey:NSLocalizedDescriptionKey]];
    }
    return NO;
#else
    if (_running || _voip) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:2
                                    userInfo:[NSDictionary dictionaryWithObject:@"An audio call is already active."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    NSDictionary *state = [[call objectForKey:@"state"] isKindOfClass:[NSDictionary class]]
        ? [call objectForKey:@"state"] : nil;
    if (![[state objectForKey:@"@type"] isEqualToString:@"callStateReady"]) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:3
                                    userInfo:[NSDictionary dictionaryWithObject:@"The call transport is not ready yet."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    NSData *keyData = TGDataFromBase64String([state objectForKey:@"encryption_key"]);
    NSArray *servers = [[state objectForKey:@"servers"] isKindOfClass:[NSArray class]]
        ? [state objectForKey:@"servers"] : nil;
    if ([keyData length] != 256 || [servers count] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:4
                                    userInfo:[NSDictionary dictionaryWithObject:@"Telegram returned incomplete audio-call transport data."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    std::vector<TgVoipEndpoint> endpoints;
    NSUInteger index = 0;
    for (index = 0; index < [servers count]; index++) {
        NSDictionary *server = [[servers objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [servers objectAtIndex:index] : nil;
        NSDictionary *serverType = [[server objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
            ? [server objectForKey:@"type"] : nil;
        NSData *peerTag = TGDataFromBase64String([serverType objectForKey:@"peer_tag"]);
        if (!server || [peerTag length] != 16) {
            continue;
        }
        TgVoipEndpoint endpoint;
        endpoint.endpointId = [[server objectForKey:@"id"] longLongValue];
        endpoint.host.ipv4 = [[[server objectForKey:@"ip_address"] description] UTF8String];
        endpoint.host.ipv6 = [[[server objectForKey:@"ipv6_address"] description] UTF8String];
        endpoint.port = (uint16_t)[[server objectForKey:@"port"] unsignedIntegerValue];
        endpoint.type = TGEndpointTypeForServer(server);
        memcpy(endpoint.peerTag, [peerTag bytes], 16);
        endpoints.push_back(endpoint);
    }
    if (endpoints.empty()) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:5
                                    userInfo:[NSDictionary dictionaryWithObject:@"No compatible Telegram call relay was returned."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    NSString *serverConfig = [[state objectForKey:@"config"] isKindOfClass:[NSString class]]
        ? [state objectForKey:@"config"] : @"{}";
    TgVoip::setGlobalServerConfig([serverConfig UTF8String]);

    TgVoipConfig config;
    config.initializationTimeout = 30.0;
    config.receiveTimeout = 20.0;
    config.dataSaving = TgVoipDataSaving::Never;
    config.enableP2P = [[state objectForKey:@"allow_p2p"] boolValue];
    config.enableAEC = true;
    config.enableNS = true;
    config.enableAGC = true;
    config.enableVolumeControl = true;
    NSString *transportLogPath = TGCallTransportLogPath();
    if ([transportLogPath length]) {
        config.logPath = [transportLogPath fileSystemRepresentation];
    }
    NSDictionary *remoteProtocol = [[state objectForKey:@"protocol"] isKindOfClass:[NSDictionary class]]
        ? [state objectForKey:@"protocol"] : nil;
    NSInteger remoteMaxLayer = [[remoteProtocol objectForKey:@"max_layer"] respondsToSelector:@selector(integerValue)]
        ? [[remoteProtocol objectForKey:@"max_layer"] integerValue] : 0;
    NSInteger localMaxLayer = (NSInteger)TgVoip::getConnectionMaxLayer();
    config.maxApiLayer = (int)(remoteMaxLayer > 0
        ? MIN(remoteMaxLayer, localMaxLayer)
        : localMaxLayer);

    TgVoipEncryptionKey encryptionKey;
    const uint8_t *keyBytes = (const uint8_t *)[keyData bytes];
    encryptionKey.value.assign(keyBytes, keyBytes + [keyData length]);
    encryptionKey.isOutgoing = [[call objectForKey:@"is_outgoing"] boolValue];

    TgVoipCrypto crypto;
    crypto.rand_bytes = &TGCallRandomBytes;
    crypto.sha1 = &TGCallSHA1;
    crypto.sha256 = &TGCallSHA256;
    crypto.aes_ige_encrypt = &TGCallAESIGEEncrypt;
    crypto.aes_ige_decrypt = &TGCallAESIGEDecrypt;
    crypto.aes_ctr_encrypt = &TGCallAESCTREncrypt;

    std::unique_ptr<TgVoip> instance = TgVoip::makeInstance(config,
                                                            TgVoipPersistentState(),
                                                            endpoints,
                                                            NULL,
                                                            TgVoipNetworkType::WiFi,
                                                            encryptionKey,
                                                            crypto);
    _voip = instance.release();
    if (!_voip) {
        if (error) {
            *error = [NSError errorWithDomain:TGCallAudioEngineErrorDomain
                                        code:6
                                    userInfo:[NSDictionary dictionaryWithObject:@"The audio engine could not be created."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    TGCallAudioEngine *owner = self;
    ((TgVoip *)_voip)->setOnStateUpdated([owner](TgVoipState stateValue) {
        TGCallAudioEngineState mappedState = TGCallAudioEngineStateConnecting;
        if (stateValue == TgVoipState::Established) {
            mappedState = TGCallAudioEngineStateEstablished;
        } else if (stateValue == TgVoipState::Reconnecting) {
            mappedState = TGCallAudioEngineStateReconnecting;
        } else if (stateValue == TgVoipState::Failed) {
            mappedState = TGCallAudioEngineStateFailed;
        }
        [owner performSelectorOnMainThread:@selector(deliverStateNumber:)
                               withObject:[NSNumber numberWithInteger:mappedState]
                            waitUntilDone:NO];
    });
    ((TgVoip *)_voip)->setOnSignalBarsUpdated([owner](int bars) {
        [owner performSelectorOnMainThread:@selector(deliverSignalBarsNumber:)
                               withObject:[NSNumber numberWithInteger:MAX(0, bars)]
                            waitUntilDone:NO];
    });
    _running = YES;
    [self deliverStateNumber:[NSNumber numberWithInteger:TGCallAudioEngineStateConnecting]];
    return YES;
#endif
}

- (void)setMicrophoneMuted:(BOOL)muted {
#if TELEGRAPHICA_HAS_TGVOIP
    if (_voip) {
        ((TgVoip *)_voip)->setMuteMicrophone(muted);
    }
#else
    (void)muted;
#endif
}

- (void)setSpeakerMuted:(BOOL)muted {
#if TELEGRAPHICA_HAS_TGVOIP
    if (_voip) {
        ((TgVoip *)_voip)->setOutputVolume(muted ? 0.0f : 1.0f);
    }
#else
    (void)muted;
#endif
}

- (void)stop {
#if TELEGRAPHICA_HAS_TGVOIP
    if (_voip) {
        TgVoip *voip = (TgVoip *)_voip;
        voip->setOnStateUpdated(std::function<void(TgVoipState)>());
        voip->setOnSignalBarsUpdated(std::function<void(int)>());
        long long relayID = voip->getPreferredRelayId();
        TgVoipFinalState finalState = voip->stop();
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:
            @"Audio call: transport stopped; Wi-Fi sent=%llu received=%llu, mobile sent=%llu received=%llu.",
            (unsigned long long)finalState.trafficStats.bytesSentWifi,
            (unsigned long long)finalState.trafficStats.bytesReceivedWifi,
            (unsigned long long)finalState.trafficStats.bytesSentMobile,
            (unsigned long long)finalState.trafficStats.bytesReceivedMobile]];
        [_preferredRelayID release];
        _preferredRelayID = [[NSNumber alloc] initWithLongLong:relayID];
        delete voip;
        _voip = NULL;
    }
#endif
    if (_running) {
        _running = NO;
        [self deliverStateNumber:[NSNumber numberWithInteger:TGCallAudioEngineStateStopped]];
    }
}

- (void)deliverStateNumber:(NSNumber *)stateNumber {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didChangeState:)]) {
        [delegate callAudioEngine:self didChangeState:(TGCallAudioEngineState)[stateNumber integerValue]];
    }
}

- (void)deliverSignalBarsNumber:(NSNumber *)signalBarsNumber {
    id<TGCallAudioEngineDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(callAudioEngine:didChangeSignalBars:)]) {
        [delegate callAudioEngine:self didChangeSignalBars:[signalBarsNumber unsignedIntegerValue]];
    }
}

- (void)dealloc {
    [self stop];
    [_preferredRelayID release];
    [super dealloc];
}

@end
