#import <Foundation/Foundation.h>

#include "TGModernCallTransport.h"

#include "tgcalls/Instance.h"
#include "tgcalls/InstanceImpl.h"
#include "tgcalls/platform/PlatformInterface.h"
#include "tgcalls/v2/InstanceV2Impl.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace {

struct AudioOutputState {
    std::atomic<bool> muted;

    AudioOutputState() : muted(false) {
    }
};

/*
 * InstanceV2Impl::setOutputVolume() is intentionally empty in the tgcalls
 * revision used by Telegraphica.  Muting the CoreAudio device itself would
 * also mute every other application on the Mac.  Intercept the per-call
 * playout callback instead: WebRTC still receives the unmodified render
 * stream for echo cancellation, while only the samples handed to CoreAudio
 * are silenced.
 */
class MutingAudioTransport final : public webrtc::AudioTransport {
public:
    explicit MutingAudioTransport(std::shared_ptr<AudioOutputState> state)
        : _state(std::move(state)), _delegate(nullptr) {
    }

    void setDelegate(webrtc::AudioTransport *delegate) {
        _delegate.store(delegate, std::memory_order_release);
    }

    int32_t RecordedDataIsAvailable(const void *audioSamples,
                                    size_t nSamples,
                                    size_t nBytesPerSample,
                                    size_t nChannels,
                                    uint32_t samplesPerSec,
                                    uint32_t totalDelayMS,
                                    int32_t clockDrift,
                                    uint32_t currentMicLevel,
                                    bool keyPressed,
                                    uint32_t &newMicLevel) override {
        webrtc::AudioTransport *delegate = currentDelegate();
        return delegate
            ? delegate->RecordedDataIsAvailable(
                audioSamples,
                nSamples,
                nBytesPerSample,
                nChannels,
                samplesPerSec,
                totalDelayMS,
                clockDrift,
                currentMicLevel,
                keyPressed,
                newMicLevel)
            : 0;
    }

    int32_t RecordedDataIsAvailable(const void *audioSamples,
                                    size_t nSamples,
                                    size_t nBytesPerSample,
                                    size_t nChannels,
                                    uint32_t samplesPerSec,
                                    uint32_t totalDelayMS,
                                    int32_t clockDrift,
                                    uint32_t currentMicLevel,
                                    bool keyPressed,
                                    uint32_t &newMicLevel,
                                    int64_t estimatedCaptureTimeNS) override {
        webrtc::AudioTransport *delegate = currentDelegate();
        return delegate
            ? delegate->RecordedDataIsAvailable(
                audioSamples,
                nSamples,
                nBytesPerSample,
                nChannels,
                samplesPerSec,
                totalDelayMS,
                clockDrift,
                currentMicLevel,
                keyPressed,
                newMicLevel,
                estimatedCaptureTimeNS)
            : 0;
    }

    int32_t NeedMorePlayData(size_t nSamples,
                             size_t nBytesPerSample,
                             size_t nChannels,
                             uint32_t samplesPerSec,
                             void *audioSamples,
                             size_t &nSamplesOut,
                             int64_t *elapsedTimeMS,
                             int64_t *ntpTimeMS) override {
        webrtc::AudioTransport *delegate = currentDelegate();
        int32_t result = 0;
        if (delegate) {
            result = delegate->NeedMorePlayData(
                nSamples,
                nBytesPerSample,
                nChannels,
                samplesPerSec,
                audioSamples,
                nSamplesOut,
                elapsedTimeMS,
                ntpTimeMS);
        } else {
            nSamplesOut = 0;
        }
        if (_state->muted.load(std::memory_order_acquire) && audioSamples) {
            std::memset(audioSamples, 0, nSamples * nBytesPerSample);
        }
        return result;
    }

    void PullRenderData(int bitsPerSample,
                        int sampleRate,
                        size_t numberOfChannels,
                        size_t numberOfFrames,
                        void *audioData,
                        int64_t *elapsedTimeMS,
                        int64_t *ntpTimeMS) override {
        webrtc::AudioTransport *delegate = currentDelegate();
        if (delegate) {
            delegate->PullRenderData(
                bitsPerSample,
                sampleRate,
                numberOfChannels,
                numberOfFrames,
                audioData,
                elapsedTimeMS,
                ntpTimeMS);
        }
        if (_state->muted.load(std::memory_order_acquire) && audioData) {
            const size_t bytesPerSample = static_cast<size_t>(bitsPerSample / 8);
            std::memset(
                audioData,
                0,
                numberOfFrames * numberOfChannels * bytesPerSample);
        }
    }

private:
    webrtc::AudioTransport *currentDelegate() const {
        return _delegate.load(std::memory_order_acquire);
    }

    std::shared_ptr<AudioOutputState> _state;
    std::atomic<webrtc::AudioTransport *> _delegate;
};

class MutingAudioDeviceModule
    : public tgcalls::DefaultWrappedAudioDeviceModule {
public:
    MutingAudioDeviceModule(
            rtc::scoped_refptr<webrtc::AudioDeviceModule> implementation,
            std::shared_ptr<AudioOutputState> state)
        : tgcalls::DefaultWrappedAudioDeviceModule(implementation),
          _transport(std::move(state)) {
    }

    int32_t RegisterAudioCallback(webrtc::AudioTransport *callback) override {
        _transport.setDelegate(callback);
        return WrappedInstance()->RegisterAudioCallback(
            callback ? &_transport : nullptr);
    }

private:
    MutingAudioTransport _transport;
};

struct TransportContext {
    std::unique_ptr<tgcalls::Instance> instance;
    std::shared_ptr<AudioOutputState> audioOutputState;
    TGModernCallCallbacks callbacks;
    void *callbackContext = nullptr;
};

void CopyError(NSString *message, char *buffer, size_t length) {
    if (!buffer || length == 0) {
        return;
    }
    const char *utf8 = [message length] > 0 ? [message UTF8String] : "Unknown call transport error.";
    std::strncpy(buffer, utf8 ? utf8 : "Unknown call transport error.", length - 1);
    buffer[length - 1] = '\0';
}

NSString *StringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

BOOL CustomParametersUseMtProto(NSString *parameters) {
    if (![parameters length]) {
        return NO;
    }
    NSData *data = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *object = data
        ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]
        : nil;
    return [object isKindOfClass:[NSDictionary class]] &&
        [[object objectForKey:@"network_use_mtproto"] boolValue];
}

NSData *Base64Data(id value) {
    NSString *string = StringValue(value);
    if (![string length]) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[[NSData alloc] initWithBase64Encoding:string] autorelease];
#pragma clang diagnostic pop
}

std::string UTF8String(id value) {
    NSString *string = StringValue(value);
    const char *utf8 = [string UTF8String];
    return utf8 ? std::string(utf8) : std::string();
}

std::string HexString(NSData *data) {
    if (![data length]) {
        return std::string();
    }
    static const char digits[] = "0123456789abcdef";
    const uint8_t *bytes = static_cast<const uint8_t *>([data bytes]);
    std::string result;
    result.reserve([data length] * 2);
    for (NSUInteger index = 0; index < [data length]; index++) {
        result.push_back(digits[(bytes[index] >> 4) & 0x0f]);
        result.push_back(digits[bytes[index] & 0x0f]);
    }
    return result;
}

void AppendHostRtcServer(std::vector<tgcalls::RtcServer> &servers,
                         NSString *host,
                         uint16_t port,
                         NSString *username,
                         NSString *password,
                         bool turn) {
    if (![host length]) {
        return;
    }
    tgcalls::RtcServer server;
    server.host = UTF8String(host);
    server.port = port;
    server.login = UTF8String(username);
    server.password = UTF8String(password);
    server.isTurn = turn;
    servers.push_back(std::move(server));
}

int StateValue(tgcalls::State state) {
    switch (state) {
        case tgcalls::State::Established:
            return 2;
        case tgcalls::State::Failed:
            return 4;
        case tgcalls::State::Reconnecting:
            return 3;
        case tgcalls::State::WaitInit:
        case tgcalls::State::WaitInitAck:
            return 1;
    }
    return 1;
}

bool VersionIsSupported(NSString *version) {
    return [version isEqualToString:@"9.0.0"] ||
        [version isEqualToString:@"8.0.0"] ||
        [version isEqualToString:@"7.0.0"] ||
        [version isEqualToString:@"3.0.0"] ||
        [version isEqualToString:@"2.7.7"];
}

NSString *SelectedVersion(NSDictionary *protocol) {
    NSArray *versions = [[protocol objectForKey:@"library_versions"] isKindOfClass:[NSArray class]]
        ? [protocol objectForKey:@"library_versions"] : nil;
    for (id value in versions) {
        NSString *version = StringValue(value);
        if (VersionIsSupported(version)) {
            return version;
        }
    }
    return nil;
}

const bool RegisteredLegacy = tgcalls::Register<tgcalls::InstanceImpl>();
const bool RegisteredV2 = tgcalls::Register<tgcalls::InstanceV2Impl>();
const bool Registered = RegisteredLegacy && RegisteredV2;

} // namespace

extern "C" int TGModernCallTransportABIVersion(void) {
    return TG_MODERN_CALL_TRANSPORT_ABI_VERSION;
}

extern "C" const char *TGModernCallTransportVersions(void) {
    return "9.0.0,8.0.0,7.0.0,3.0.0,2.7.7";
}

extern "C" int TGModernCallTransportMaxLayer(void) {
    return Registered ? tgcalls::Meta::MaxLayer() : 0;
}

extern "C" void *TGModernCallTransportCreate(const char *callJSON,
                                              TGModernCallCallbacks callbacks,
                                              void *context,
                                              char *errorBuffer,
                                              size_t errorBufferLength) {
    @autoreleasepool {
        if (!Registered || !callJSON) {
            CopyError(@"The modern Telegram call engine is unavailable.", errorBuffer, errorBufferLength);
            return nullptr;
        }
        NSData *jsonData = [NSData dataWithBytes:callJSON length:std::strlen(callJSON)];
        NSError *jsonError = nil;
        NSDictionary *call = [NSJSONSerialization JSONObjectWithData:jsonData
                                                             options:0
                                                               error:&jsonError];
        if (![call isKindOfClass:[NSDictionary class]]) {
            CopyError([jsonError localizedDescription] ?: @"Telegram returned invalid call data.",
                      errorBuffer,
                      errorBufferLength);
            return nullptr;
        }
        NSDictionary *state = [[call objectForKey:@"state"] isKindOfClass:[NSDictionary class]]
            ? [call objectForKey:@"state"] : nil;
        if (![[state objectForKey:@"@type"] isEqualToString:@"callStateReady"]) {
            CopyError(@"Telegram call transport is not ready.", errorBuffer, errorBufferLength);
            return nullptr;
        }
        NSDictionary *protocol = [[state objectForKey:@"protocol"] isKindOfClass:[NSDictionary class]]
            ? [state objectForKey:@"protocol"] : nil;
        NSString *version = SelectedVersion(protocol);
        if (![version length]) {
            CopyError(@"Telegram selected an unsupported call protocol.", errorBuffer, errorBufferLength);
            return nullptr;
        }
        NSData *keyData = Base64Data([state objectForKey:@"encryption_key"]);
        if ([keyData length] != tgcalls::EncryptionKey::kSize) {
            CopyError(@"Telegram returned an invalid call encryption key.", errorBuffer, errorBufferLength);
            return nullptr;
        }

        std::shared_ptr<std::array<uint8_t, tgcalls::EncryptionKey::kSize>> key(
            new std::array<uint8_t, tgcalls::EncryptionKey::kSize>());
        std::memcpy(key->data(), [keyData bytes], key->size());
        tgcalls::Descriptor descriptor = {
            .encryptionKey = tgcalls::EncryptionKey(
                key,
                [[call objectForKey:@"is_outgoing"] boolValue])
        };
        descriptor.version = UTF8String(version);
        descriptor.config.initializationTimeout = 30.0;
        descriptor.config.receiveTimeout = 20.0;
        descriptor.config.dataSaving = tgcalls::DataSaving::Never;
        descriptor.config.enableP2P = [[state objectForKey:@"allow_p2p"] boolValue];
        /*
         * Telegram supplies both UDP and TCP reflector endpoints.  Some home,
         * office, carrier, and VPN paths block or degrade UDP; disabling TCP
         * left those calls permanently reconnecting after signaling succeeded.
         */
        descriptor.config.allowTCP = true;
        descriptor.config.enableAEC = true;
        descriptor.config.enableNS = true;
        descriptor.config.enableAGC = true;
        descriptor.config.enableVolumeControl = true;
        descriptor.config.maxApiLayer = [[protocol objectForKey:@"max_layer"] intValue];
        NSString *customParameters = StringValue([state objectForKey:@"custom_parameters"]);
        /*
         * Only use transport experiments that Telegram explicitly supplied for
         * this call.  In particular, forcing network_use_mtproto when the field
         * is absent makes our side treat writable ICE as an established media
         * connection while an ordinary Telegram peer is waiting for DTLS-SRTP.
         */
        descriptor.config.customParameters = UTF8String(customParameters);
        descriptor.config.protocolVersion = [version isEqualToString:@"3.0.0"]
            ? tgcalls::ProtocolVersion::V1 : tgcalls::ProtocolVersion::V0;
        descriptor.config.logPath.data = "/tmp/TelegraphicaCallTransport.log";
        descriptor.config.statsLogPath.data = "/tmp/TelegraphicaCallTransportStats.json";
        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/TelegraphicaCallTransport.log"
                                                   error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:@"/tmp/TelegraphicaCallTransportStats.json"
                                                   error:nil];
        descriptor.initialNetworkType = tgcalls::NetworkType::WiFi;
        descriptor.mediaDevicesConfig.inputVolume = 1.0f;
        descriptor.mediaDevicesConfig.outputVolume = 1.0f;
        std::shared_ptr<AudioOutputState> audioOutputState(new AudioOutputState());
        descriptor.createAudioDeviceModule =
            [audioOutputState](webrtc::TaskQueueFactory *taskQueueFactory) {
                rtc::scoped_refptr<webrtc::AudioDeviceModule> implementation =
                    webrtc::AudioDeviceModule::Create(
                        webrtc::AudioDeviceModule::kPlatformDefaultAudio,
                        taskQueueFactory);
                if (!implementation) {
                    return rtc::scoped_refptr<webrtc::AudioDeviceModule>();
                }
                return rtc::scoped_refptr<webrtc::AudioDeviceModule>(
                    rtc::make_ref_counted<MutingAudioDeviceModule>(
                        implementation,
                        audioOutputState));
            };

        NSUInteger udpReflectorCount = 0;
        NSUInteger tcpReflectorCount = 0;
        NSUInteger stunServerCount = 0;
        NSUInteger turnServerCount = 0;
        NSArray *servers = [[state objectForKey:@"servers"] isKindOfClass:[NSArray class]]
            ? [state objectForKey:@"servers"] : nil;
        std::vector<int64_t> reflectorIdentifiers;
        for (id value in servers) {
            NSDictionary *server = [value isKindOfClass:[NSDictionary class]] ? value : nil;
            NSDictionary *type = [[server objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
                ? [server objectForKey:@"type"] : nil;
            if ([[type objectForKey:@"@type"] isEqualToString:@"callServerTypeTelegramReflector"]) {
                reflectorIdentifiers.push_back([[server objectForKey:@"id"] longLongValue]);
            }
        }
        std::sort(reflectorIdentifiers.begin(), reflectorIdentifiers.end());
        reflectorIdentifiers.erase(
            std::unique(reflectorIdentifiers.begin(), reflectorIdentifiers.end()),
            reflectorIdentifiers.end());
        for (id value in servers) {
            NSDictionary *server = [value isKindOfClass:[NSDictionary class]] ? value : nil;
            NSDictionary *type = [[server objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
                ? [server objectForKey:@"type"] : nil;
            NSString *typeName = StringValue([type objectForKey:@"@type"]);
            uint16_t port = (uint16_t)[[server objectForKey:@"port"] unsignedIntegerValue];
            if ([typeName isEqualToString:@"callServerTypeTelegramReflector"]) {
                NSData *peerTag = Base64Data([type objectForKey:@"peer_tag"]);
                if ([peerTag length] != 16) {
                    continue;
                }
                tgcalls::Endpoint endpoint;
                endpoint.endpointId = [[server objectForKey:@"id"] longLongValue];
                endpoint.host.ipv4 = UTF8String([server objectForKey:@"ip_address"]);
                endpoint.host.ipv6 = UTF8String([server objectForKey:@"ipv6_address"]);
                endpoint.port = port;
                endpoint.type = [[type objectForKey:@"is_tcp"] boolValue]
                    ? tgcalls::EndpointType::TcpRelay
                    : tgcalls::EndpointType::UdpRelay;
                if ([[type objectForKey:@"is_tcp"] boolValue]) {
                    tcpReflectorCount++;
                } else {
                    udpReflectorCount++;
                }
                std::memcpy(endpoint.peerTag, [peerTag bytes], 16);
                descriptor.endpoints.push_back(std::move(endpoint));

                /*
                 * Protocols 7–9 advertise synthetic reflector candidates.
                 * They must be handled by ReflectorPort so STUN and media are
                 * wrapped in Telegram's reflector framing; ordinary UDP sent
                 * directly to the published 91.108.x.x relay never receives a
                 * response.
                 */
                std::vector<int64_t>::const_iterator reflectorIterator =
                    std::lower_bound(reflectorIdentifiers.begin(),
                                     reflectorIdentifiers.end(),
                                     [[server objectForKey:@"id"] longLongValue]);
                uint8_t reflectorID = reflectorIterator != reflectorIdentifiers.end()
                    ? static_cast<uint8_t>(
                        std::distance(reflectorIdentifiers.cbegin(), reflectorIterator) + 1)
                    : 0;
                if (reflectorID > 0) {
                    NSString *ipv4 = StringValue([server objectForKey:@"ip_address"]);
                    NSString *ipv6 = StringValue([server objectForKey:@"ipv6_address"]);
                    const bool isTCP = [[type objectForKey:@"is_tcp"] boolValue];
                    const std::string peerTagHex = HexString(peerTag);
                    if ([ipv4 length]) {
                        tgcalls::RtcServer rtcServer;
                        rtcServer.id = reflectorID;
                        rtcServer.host = UTF8String(ipv4);
                        rtcServer.port = port;
                        rtcServer.login = "reflector";
                        rtcServer.password = peerTagHex;
                        rtcServer.isTurn = true;
                        rtcServer.isTcp = isTCP;
                        descriptor.rtcServers.push_back(std::move(rtcServer));
                    }
                    if ([ipv6 length]) {
                        tgcalls::RtcServer rtcServer;
                        rtcServer.id = reflectorID;
                        rtcServer.host = UTF8String(ipv6);
                        rtcServer.port = port;
                        rtcServer.login = "reflector";
                        rtcServer.password = peerTagHex;
                        rtcServer.isTurn = true;
                        rtcServer.isTcp = isTCP;
                        descriptor.rtcServers.push_back(std::move(rtcServer));
                    }
                }
            } else if ([typeName isEqualToString:@"callServerTypeWebRTC"]) {
                NSString *ipv4 = StringValue([server objectForKey:@"ip_address"]);
                NSString *ipv6 = StringValue([server objectForKey:@"ipv6_address"]);
                NSString *username = StringValue([type objectForKey:@"username"]);
                NSString *password = StringValue([type objectForKey:@"password"]);
                if ([[type objectForKey:@"supports_stun"] boolValue]) {
                    AppendHostRtcServer(descriptor.rtcServers, ipv4, port, @"", @"", false);
                    AppendHostRtcServer(descriptor.rtcServers, ipv6, port, @"", @"", false);
                    stunServerCount += ([ipv4 length] > 0 ? 1U : 0U);
                    stunServerCount += ([ipv6 length] > 0 ? 1U : 0U);
                }
                if ([[type objectForKey:@"supports_turn"] boolValue] &&
                    [username length] > 0 && [password length] > 0) {
                    AppendHostRtcServer(descriptor.rtcServers, ipv4, port, username, password, true);
                    AppendHostRtcServer(descriptor.rtcServers, ipv6, port, username, password, true);
                    turnServerCount += ([ipv4 length] > 0 ? 1U : 0U);
                    turnServerCount += ([ipv6 length] > 0 ? 1U : 0U);
                }
            }
        }
        if (descriptor.endpoints.empty() && descriptor.rtcServers.empty()) {
            CopyError(@"Telegram returned no compatible call servers.", errorBuffer, errorBufferLength);
            return nullptr;
        }
        if (callbacks.logMessage) {
            NSString *summary = [NSString stringWithFormat:
                @"Transport configuration: protocol=%@ p2p=%@ UDP reflectors=%lu "
                 "TCP reflectors=%lu STUN=%lu TURN=%lu custom-parameters=%@ "
                 "media-transport=%@.",
                version,
                descriptor.config.enableP2P ? @"yes" : @"no",
                (unsigned long)udpReflectorCount,
                (unsigned long)tcpReflectorCount,
                (unsigned long)stunServerCount,
                (unsigned long)turnServerCount,
                [customParameters length] > 0 ? @"present" : @"absent",
                CustomParametersUseMtProto(customParameters) ? @"mtproto" : @"dtls-srtp"];
            callbacks.logMessage(context, [summary UTF8String]);
        }

        std::unique_ptr<TransportContext> owner(new TransportContext());
        owner->audioOutputState = audioOutputState;
        owner->callbacks = callbacks;
        owner->callbackContext = context;
        TransportContext *rawOwner = owner.get();
        descriptor.stateUpdated = [rawOwner](tgcalls::State stateValue) {
            if (rawOwner->callbacks.stateChanged) {
                rawOwner->callbacks.stateChanged(rawOwner->callbackContext, StateValue(stateValue));
            }
        };
        descriptor.signalBarsUpdated = [rawOwner](int bars) {
            if (rawOwner->callbacks.signalBarsChanged) {
                rawOwner->callbacks.signalBarsChanged(rawOwner->callbackContext, bars);
            }
        };
        descriptor.signalingDataEmitted = [rawOwner](const std::vector<uint8_t> &data) {
            if (rawOwner->callbacks.signalingDataEmitted && !data.empty()) {
                rawOwner->callbacks.signalingDataEmitted(
                    rawOwner->callbackContext,
                    data.data(),
                    data.size());
            }
        };
        descriptor.remoteBatteryLevelIsLowUpdated = [](bool value) { (void)value; };
        descriptor.remoteMediaStateUpdated = [](tgcalls::AudioState audio, tgcalls::VideoState video) {
            (void)audio;
            (void)video;
        };
        descriptor.remotePrefferedAspectRatioUpdated = [](float value) { (void)value; };

        owner->instance = tgcalls::Meta::Create(UTF8String(version), std::move(descriptor));
        if (!owner->instance) {
            CopyError(@"The modern Telegram call engine could not be created.",
                      errorBuffer,
                      errorBufferLength);
            return nullptr;
        }
        if (callbacks.logMessage) {
            std::string message = std::string("Modern call transport started with protocol ") +
                UTF8String(version) + ".";
            callbacks.logMessage(context, message.c_str());
        }
        return owner.release();
    }
}

extern "C" void TGModernCallTransportReceiveSignalingData(void *transport,
                                                           const uint8_t *bytes,
                                                           size_t length) {
    TransportContext *owner = static_cast<TransportContext *>(transport);
    if (!owner || !owner->instance || !bytes || length == 0) {
        return;
    }
    owner->instance->receiveSignalingData(std::vector<uint8_t>(bytes, bytes + length));
}

extern "C" void TGModernCallTransportSetMicrophoneMuted(void *transport, int muted) {
    TransportContext *owner = static_cast<TransportContext *>(transport);
    if (owner && owner->instance) {
        owner->instance->setMuteMicrophone(muted != 0);
    }
}

extern "C" void TGModernCallTransportSetSpeakerMuted(void *transport, int muted) {
    TransportContext *owner = static_cast<TransportContext *>(transport);
    if (owner && owner->audioOutputState) {
        owner->audioOutputState->muted.store(muted != 0, std::memory_order_release);
    }
}

extern "C" int64_t TGModernCallTransportPreferredRelayID(void *transport) {
    TransportContext *owner = static_cast<TransportContext *>(transport);
    return (owner && owner->instance) ? owner->instance->getPreferredRelayId() : 0;
}

extern "C" void TGModernCallTransportStop(void *transport) {
    std::unique_ptr<TransportContext> owner(static_cast<TransportContext *>(transport));
    if (!owner || !owner->instance) {
        return;
    }
    std::mutex mutex;
    std::condition_variable condition;
    bool finished = false;
    owner->instance->stop([&](tgcalls::FinalState finalState) {
        (void)finalState;
        std::lock_guard<std::mutex> lock(mutex);
        finished = true;
        condition.notify_all();
    });
    std::unique_lock<std::mutex> lock(mutex);
    condition.wait_for(lock, std::chrono::seconds(3), [&] { return finished; });
    owner->instance.reset();
    if (owner->callbacks.stateChanged) {
        owner->callbacks.stateChanged(owner->callbackContext, 5);
    }
}
