#import <Foundation/Foundation.h>

#include "TGModernCallTransport.h"

#include "tgcalls/Instance.h"
#include "tgcalls/InstanceImpl.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace {

struct TransportContext {
    std::unique_ptr<tgcalls::Instance> instance;
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
    return [version isEqualToString:@"3.0.0"] || [version isEqualToString:@"2.7.7"];
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

const bool Registered = tgcalls::Register<tgcalls::InstanceImpl>();

} // namespace

extern "C" int TGModernCallTransportABIVersion(void) {
    return TG_MODERN_CALL_TRANSPORT_ABI_VERSION;
}

extern "C" const char *TGModernCallTransportVersions(void) {
    return "3.0.0,2.7.7";
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
        descriptor.config.protocolVersion = [version isEqualToString:@"3.0.0"]
            ? tgcalls::ProtocolVersion::V1 : tgcalls::ProtocolVersion::V0;
        descriptor.initialNetworkType = tgcalls::NetworkType::WiFi;
        descriptor.mediaDevicesConfig.inputVolume = 1.0f;
        descriptor.mediaDevicesConfig.outputVolume = 1.0f;

        NSArray *servers = [[state objectForKey:@"servers"] isKindOfClass:[NSArray class]]
            ? [state objectForKey:@"servers"] : nil;
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
                std::memcpy(endpoint.peerTag, [peerTag bytes], 16);
                descriptor.endpoints.push_back(std::move(endpoint));
            } else if ([typeName isEqualToString:@"callServerTypeWebRTC"]) {
                NSString *ipv4 = StringValue([server objectForKey:@"ip_address"]);
                NSString *ipv6 = StringValue([server objectForKey:@"ipv6_address"]);
                NSString *username = StringValue([type objectForKey:@"username"]);
                NSString *password = StringValue([type objectForKey:@"password"]);
                if ([[type objectForKey:@"supports_stun"] boolValue]) {
                    AppendHostRtcServer(descriptor.rtcServers, ipv4, port, @"", @"", false);
                    AppendHostRtcServer(descriptor.rtcServers, ipv6, port, @"", @"", false);
                }
                if ([[type objectForKey:@"supports_turn"] boolValue] &&
                    [username length] > 0 && [password length] > 0) {
                    AppendHostRtcServer(descriptor.rtcServers, ipv4, port, username, password, true);
                    AppendHostRtcServer(descriptor.rtcServers, ipv6, port, username, password, true);
                }
            }
        }
        if (descriptor.endpoints.empty() && descriptor.rtcServers.empty()) {
            CopyError(@"Telegram returned no compatible call servers.", errorBuffer, errorBufferLength);
            return nullptr;
        }

        std::unique_ptr<TransportContext> owner(new TransportContext());
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
    if (owner && owner->instance) {
        owner->instance->setOutputVolume(muted ? 0.0f : 1.0f);
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
