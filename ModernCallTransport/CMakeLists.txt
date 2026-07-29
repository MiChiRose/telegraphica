cmake_minimum_required(VERSION 3.16)
project(TelegraphicaCallTransport LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "Minimum OS X version" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(TGCALLS_SOURCE_DIR "" CACHE PATH "Path to the pinned tgcalls checkout")
set(TG_OWT_SOURCE_DIR "" CACHE PATH "Path to the matching tg_owt checkout")
set(TG_OWT_LIBRARY "" CACHE FILEPATH "Path to the matching libtg_owt.a")
set(OPENSSL_ROOT "" CACHE PATH "Path to the Intel OpenSSL prefix")
set(OPUS_ROOT "" CACHE PATH "Path to the Intel Opus prefix")

foreach(required
        TGCALLS_SOURCE_DIR
        TG_OWT_SOURCE_DIR
        TG_OWT_LIBRARY
        OPENSSL_ROOT
        OPUS_ROOT)
    if("${${required}}" STREQUAL "")
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

set(TGCALLS_DIR "${TGCALLS_SOURCE_DIR}/tgcalls")
add_library(TelegraphicaCallTransport SHARED
    TGModernCallTransport.mm
    TGModernCallAudioOnlyPlatform.cpp
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
    "${TG_OWT_SOURCE_DIR}/src/modules/video_coding/codecs/h264/h264.cc"
)

target_include_directories(TelegraphicaCallTransport PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${TGCALLS_SOURCE_DIR}"
    "${TGCALLS_DIR}"
    "${TG_OWT_SOURCE_DIR}/src"
    "${TG_OWT_SOURCE_DIR}/src/third_party/abseil-cpp"
    "${OPENSSL_ROOT}/include"
    "${OPUS_ROOT}/include"
    "${OPUS_ROOT}/include/opus"
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
