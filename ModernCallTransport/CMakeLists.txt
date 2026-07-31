cmake_minimum_required(VERSION 3.16)
project(TelegraphicaCallTransport LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "Minimum OS X version" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(TGCALLS_SOURCE_DIR "" CACHE PATH "Path to the pinned tgcalls checkout")
set(TG_OWT_SOURCE_DIR "" CACHE PATH "Path to the matching tg_owt checkout")
set(TG_OWT_LIBRARY "" CACHE FILEPATH "Path to the matching libtg_owt.a")
set(OPENSSL_ROOT "" CACHE PATH "Path to the Intel OpenSSL prefix")
set(OPUS_ROOT "" CACHE PATH "Path to the Intel Opus prefix")
set(VPX_ROOT "" CACHE PATH "Path to the Intel libvpx build prefix")

foreach(required
        TGCALLS_SOURCE_DIR
        TG_OWT_SOURCE_DIR
        TG_OWT_LIBRARY
        OPENSSL_ROOT
        OPUS_ROOT
        VPX_ROOT)
    if("${${required}}" STREQUAL "")
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

set(TGCALLS_DIR "${TGCALLS_SOURCE_DIR}/tgcalls")

# The pinned 2022 v2 transport creates its media engine without a WebRTC Audio
# Processing Module. Its AEC/NS/AGC flags consequently have no effect. Keep the
# dependency checkout untouched and compile a narrowly patched generated copy.
set(INSTANCE_V2_SOURCE "${TGCALLS_DIR}/v2/InstanceV2Impl.cpp")
file(READ "${INSTANCE_V2_SOURCE}" INSTANCE_V2_CONTENTS)
set(INSTANCE_V2_AUDIO_INCLUDE
    "#include \"modules/audio_processing/audio_buffer.h\"")
set(INSTANCE_V2_AUDIO_INCLUDES
    "#include \"modules/audio_processing/audio_buffer.h\"\n#include \"modules/audio_processing/include/audio_processing.h\"")
string(REPLACE
    "${INSTANCE_V2_AUDIO_INCLUDE}"
    "${INSTANCE_V2_AUDIO_INCLUDES}"
    INSTANCE_V2_WITH_AUDIO_INCLUDE
    "${INSTANCE_V2_CONTENTS}")
if(INSTANCE_V2_WITH_AUDIO_INCLUDE STREQUAL INSTANCE_V2_CONTENTS)
    message(FATAL_ERROR "Could not add the WebRTC Audio Processing include to InstanceV2Impl.cpp")
endif()
set(INSTANCE_V2_MEDIA_ENGINE_ANCHOR
    "        mediaDeps.adm = _audioDeviceModule;\n\n        _availableVideoFormats")
set(INSTANCE_V2_MEDIA_ENGINE_WITH_APM
    "        mediaDeps.adm = _audioDeviceModule;\n        webrtc::AudioProcessingBuilder audioProcessingBuilder;\n        mediaDeps.audio_processing = audioProcessingBuilder.Create();\n\n        _availableVideoFormats")
string(REPLACE
    "${INSTANCE_V2_MEDIA_ENGINE_ANCHOR}"
    "${INSTANCE_V2_MEDIA_ENGINE_WITH_APM}"
    INSTANCE_V2_PATCHED_CONTENTS
    "${INSTANCE_V2_WITH_AUDIO_INCLUDE}")
if(INSTANCE_V2_PATCHED_CONTENTS STREQUAL INSTANCE_V2_WITH_AUDIO_INCLUDE)
    message(FATAL_ERROR "Could not install WebRTC Audio Processing in InstanceV2Impl.cpp")
endif()
set(INSTANCE_V2_PATCHED_SOURCE
    "${CMAKE_CURRENT_BINARY_DIR}/TGInstanceV2ImplPatched.cpp")
file(WRITE "${INSTANCE_V2_PATCHED_SOURCE}" "${INSTANCE_V2_PATCHED_CONTENTS}")

# WebRTC needs the concrete relay address family while processing packets from
# Telegram's synthetic reflector host. Without it, ICE can select the relay but
# STUN/DTLS responses fail with "unknown family" on some peer/network routes.
# Keep the synthetic hostname for Telegram's peer-tag framing and attach only
# the already-known reflector IP, matching the newer upstream implementation.
set(REFLECTOR_PORT_SOURCE "${TGCALLS_DIR}/v2/ReflectorPort.cpp")
file(READ "${REFLECTOR_PORT_SOURCE}" REFLECTOR_PORT_CONTENTS)
set(REFLECTOR_DISPATCH_ANCHOR
    "                rtc::SocketAddress candidateAddress(\n                    hostname, server_address_.address.port());\n\n                if (dataSize > 0)")
set(REFLECTOR_DISPATCH_WITH_RESOLVED_IP
    "                rtc::SocketAddress candidateAddress(\n                    hostname, server_address_.address.port());\n                candidateAddress.SetResolvedIP(server_address_.address.ipaddr());\n\n                if (dataSize > 0)")
string(REPLACE
    "${REFLECTOR_DISPATCH_ANCHOR}"
    "${REFLECTOR_DISPATCH_WITH_RESOLVED_IP}"
    REFLECTOR_PORT_PATCHED_CONTENTS
    "${REFLECTOR_PORT_CONTENTS}")
if(REFLECTOR_PORT_PATCHED_CONTENTS STREQUAL REFLECTOR_PORT_CONTENTS)
    message(FATAL_ERROR "Could not attach the relay IP to incoming reflector packets")
endif()
set(REFLECTOR_PORT_PATCHED_SOURCE
    "${CMAKE_CURRENT_BINARY_DIR}/TGReflectorPortPatched.cpp")
file(WRITE "${REFLECTOR_PORT_PATCHED_SOURCE}" "${REFLECTOR_PORT_PATCHED_CONTENTS}")

# The legacy camera bridge uses AVFoundation directly because WebRTC's old
# VideoCaptureModule cannot open every FaceTime camera supported by Mavericks.
set_source_files_properties(TGModernCallVideoPlatform.cpp PROPERTIES LANGUAGE OBJCXX)

add_library(TelegraphicaCallTransport SHARED
    TGModernCallTransport.mm
    TGModernCallLegacyClock.cpp
    TGModernCallVideoPlatform.cpp
    "${TGCALLS_DIR}/CodecSelectHelper.cpp"
    "${TGCALLS_DIR}/CryptoHelper.cpp"
    "${TGCALLS_DIR}/EncryptedConnection.cpp"
    "${TGCALLS_DIR}/Instance.cpp"
    "${TGCALLS_DIR}/InstanceImpl.cpp"
    "${TGCALLS_DIR}/LogSinkImpl.cpp"
    "${TGCALLS_DIR}/Manager.cpp"
    "${TGCALLS_DIR}/MediaManager.cpp"
    "${TGCALLS_DIR}/Message.cpp"
    "${TGCALLS_DIR}/NetworkManager.cpp"
    "${TGCALLS_DIR}/VideoCaptureInterface.cpp"
    "${TGCALLS_DIR}/VideoCaptureInterfaceImpl.cpp"
    "${TGCALLS_DIR}/AudioDeviceHelper.cpp"
    "${TGCALLS_DIR}/FieldTrialsConfig.cpp"
    "${TGCALLS_DIR}/SctpDataChannelProviderInterfaceImpl.cpp"
    "${TGCALLS_DIR}/StaticThreads.cpp"
    "${TGCALLS_DIR}/ThreadLocalObject.cpp"
    "${TGCALLS_DIR}/TurnCustomizerImpl.cpp"
    "${TGCALLS_DIR}/third-party/json11.cpp"
    "${TGCALLS_DIR}/utils/gzip.cpp"
    "${TGCALLS_DIR}/v2/ContentNegotiation.cpp"
    "${TGCALLS_DIR}/v2/ExternalSignalingConnection.cpp"
    "${INSTANCE_V2_PATCHED_SOURCE}"
    "${TGCALLS_DIR}/v2/NativeNetworkingImpl.cpp"
    "${REFLECTOR_PORT_PATCHED_SOURCE}"
    "${TGCALLS_DIR}/v2/ReflectorRelayPortFactory.cpp"
    "${TGCALLS_DIR}/v2/Signaling.cpp"
    "${TGCALLS_DIR}/v2/SignalingConnection.cpp"
    "${TGCALLS_DIR}/v2/SignalingEncryption.cpp"
    "${TGCALLS_DIR}/v2/SignalingSctpConnection.cpp"
    "${TG_OWT_SOURCE_DIR}/src/modules/video_coding/codecs/h264/h264.cc"
)

target_include_directories(TelegraphicaCallTransport PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${TGCALLS_SOURCE_DIR}"
    "${TGCALLS_DIR}"
    "${TGCALLS_DIR}/v2"
    "${TG_OWT_SOURCE_DIR}/src"
    "${TG_OWT_SOURCE_DIR}/src/third_party/abseil-cpp"
    "${TG_OWT_SOURCE_DIR}/src/third_party/libyuv/include"
    "${OPENSSL_ROOT}/include"
    "${OPUS_ROOT}/include"
    "${OPUS_ROOT}/include/opus"
    "${VPX_ROOT}/include"
)

target_compile_definitions(TelegraphicaCallTransport PRIVATE
    WEBRTC_APP_TDESKTOP
    WEBRTC_MAC
    WEBRTC_POSIX
    RTC_ENABLE_VP9
)
target_compile_options(TelegraphicaCallTransport PRIVATE
    -Wno-deprecated-builtins
    -Wno-c++11-narrowing-const-reference
)

find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
find_library(AUDIOUNIT_FRAMEWORK AudioUnit REQUIRED)
find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)
find_library(SECURITY_FRAMEWORK Security REQUIRED)
find_library(VIDEOTOOLBOX_FRAMEWORK VideoToolbox REQUIRED)

target_link_libraries(TelegraphicaCallTransport PRIVATE
    "${TG_OWT_LIBRARY}"
    "${OPUS_ROOT}/lib/libopus.a"
    "${VPX_ROOT}/lib/libvpx.a"
    "${OPENSSL_ROOT}/lib/libssl.a"
    "${OPENSSL_ROOT}/lib/libcrypto.a"
    "${FOUNDATION_FRAMEWORK}"
    "${AVFOUNDATION_FRAMEWORK}"
    "${AUDIOTOOLBOX_FRAMEWORK}"
    "${AUDIOUNIT_FRAMEWORK}"
    "${COREAUDIO_FRAMEWORK}"
    "${COREFOUNDATION_FRAMEWORK}"
    "${COREMEDIA_FRAMEWORK}"
    "${COREVIDEO_FRAMEWORK}"
    "${SECURITY_FRAMEWORK}"
    "${VIDEOTOOLBOX_FRAMEWORK}"
    "-framework Cocoa"
    "-framework IOKit"
    "-framework OpenGL"
    "-framework QuartzCore"
    "-framework SystemConfiguration"
    "-liconv"
    "-lz"
)

set_target_properties(TelegraphicaCallTransport PROPERTIES
    OUTPUT_NAME "TelegraphicaCallTransport"
    PREFIX ""
    INSTALL_NAME_DIR "@rpath"
    BUILD_WITH_INSTALL_RPATH YES
    INSTALL_RPATH "@loader_path"
)
