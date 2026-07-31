#include "platform/PlatformInterface.h"

#include "VideoCapturerInterface.h"
#include "VideoCaptureInterface.h"
#include "api/video/i420_buffer.h"
#include "api/video/video_frame.h"
#include "api/video/video_sink_interface.h"
#include "api/video_codecs/builtin_video_decoder_factory.h"
#include "api/video_codecs/builtin_video_encoder_factory.h"
#include "media/base/codec.h"
#include "media/base/video_broadcaster.h"
#include "modules/video_capture/video_capture.h"
#include "modules/video_capture/video_capture_factory.h"
#include "pc/video_track_source.h"
#include "pc/video_track_source_proxy.h"

#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace tgcalls {
namespace {

/*
 * A deliberately small camera-only platform for the unified legacy build.
 * Telegram Desktop's generic desktop implementation also pulls in screen
 * capture and newer Darwin wrappers.  Telegraphica only needs the built-in
 * camera for one-to-one video calls, and this implementation stays within the
 * WebRTC capture APIs available on OS X 10.9.
 */
class CameraTrackSource : public webrtc::VideoTrackSource {
public:
    CameraTrackSource()
        : webrtc::VideoTrackSource(false),
          _broadcaster(std::make_shared<rtc::VideoBroadcaster>()) {
    }

    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink() const {
        return _broadcaster;
    }

private:
    rtc::VideoSourceInterface<webrtc::VideoFrame> *source() override {
        return _broadcaster.get();
    }

    std::shared_ptr<rtc::VideoBroadcaster> _broadcaster;
};

std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> SinkForSource(
        const rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> &source) {
    webrtc::VideoTrackSourceProxy *proxy =
        static_cast<webrtc::VideoTrackSourceProxy *>(source.get());
    CameraTrackSource *trackSource =
        static_cast<CameraTrackSource *>(proxy->internal());
    return trackSource->sink();
}

bool ValidCapability(const webrtc::VideoCaptureCapability &capability) {
    return capability.width > 0 && capability.height > 0 && capability.maxFPS > 0;
}

void AppendCapability(std::vector<webrtc::VideoCaptureCapability> &capabilities,
                      const webrtc::VideoCaptureCapability &capability) {
    if (!ValidCapability(capability) ||
        std::find(capabilities.begin(), capabilities.end(), capability) != capabilities.end()) {
        return;
    }
    capabilities.push_back(capability);
}

void AppendCapabilityWithI420Fallback(
        std::vector<webrtc::VideoCaptureCapability> &capabilities,
        const webrtc::VideoCaptureCapability &capability) {
    if (!ValidCapability(capability)) {
        return;
    }
    webrtc::VideoCaptureCapability converted = capability;
    converted.videoType = webrtc::VideoType::kI420;
    AppendCapability(capabilities, converted);
    AppendCapability(capabilities, capability);
}

class CameraCapturer final
    : public VideoCapturerInterface,
      public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
    CameraCapturer(
            rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
            const std::string &deviceID,
            std::function<void(VideoState)> stateUpdated,
            std::pair<int, int> &outResolution)
        : _source(source),
          _sink(SinkForSource(source)),
          _deviceID(deviceID),
          _stateUpdated(std::move(stateUpdated)) {
        outResolution = std::make_pair(640, 480);
    }

    ~CameraCapturer() override {
        stopCapture();
        setUncroppedOutput(nullptr);
    }

    void setState(VideoState state) override {
        if (_state == state) {
            return;
        }
        _state = state;
        if (state == VideoState::Active) {
            startCapture();
        } else {
            stopCapture();
        }
        if (_stateUpdated) {
            _stateUpdated(state);
        }
    }

    void setPreferredCaptureAspectRatio(float aspectRatio) override {
        _aspectRatio = aspectRatio;
    }

    void setUncroppedOutput(
            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override {
        if (_uncroppedSink) {
            _source->RemoveSink(_uncroppedSink.get());
        }
        _uncroppedSink = std::move(sink);
        if (_uncroppedSink) {
            _source->AddOrUpdateSink(_uncroppedSink.get(), rtc::VideoSinkWants());
        }
    }

    int getRotation() override {
        return 0;
    }

    void setOnFatalError(std::function<void()> error) override {
        _fatalError = std::move(error);
    }

    void OnFrame(const webrtc::VideoFrame &frame) override {
        if (_state != VideoState::Active) {
            return;
        }
        if (_aspectRatio <= 0.001f) {
            _sink->OnFrame(frame);
            return;
        }
        const int originalWidth = frame.width();
        const int originalHeight = frame.height();
        int width = originalWidth > _aspectRatio * originalHeight
            ? static_cast<int>(std::round(_aspectRatio * originalHeight))
            : originalWidth;
        int height = originalWidth > _aspectRatio * originalHeight
            ? originalHeight
            : static_cast<int>(std::round(originalWidth / _aspectRatio));
        width &= ~1;
        height &= ~1;
        if (width <= 0 || height <= 0 ||
            (width >= originalWidth && height >= originalHeight)) {
            _sink->OnFrame(frame);
            return;
        }
        rtc::scoped_refptr<webrtc::I420Buffer> cropped =
            webrtc::I420Buffer::Create(width, height);
        cropped->CropAndScaleFrom(
            *frame.video_frame_buffer()->ToI420(),
            (originalWidth - width) / 2,
            (originalHeight - height) / 2,
            width,
            height);
        _sink->OnFrame(
            webrtc::VideoFrame::Builder()
                .set_video_frame_buffer(cropped)
                .set_rotation(webrtc::kVideoRotation_0)
                .set_timestamp_us(frame.timestamp_us())
                .set_id(frame.id())
                .build());
    }

private:
    void reportFailure() {
        if (_fatalError) {
            _fatalError();
        }
    }

    void startCapture() {
        stopCapture();
        std::unique_ptr<webrtc::VideoCaptureModule::DeviceInfo> info(
            webrtc::VideoCaptureFactory::CreateDeviceInfo());
        if (!info || info->NumberOfDevices() <= 0) {
            reportFailure();
            return;
        }
        const int count = info->NumberOfDevices();
        std::string selectedID;
        for (int index = 0; index < count; ++index) {
            char name[256] = { 0 };
            char identifier[256] = { 0 };
            if (info->GetDeviceName(index, name, sizeof(name),
                                    identifier, sizeof(identifier)) != 0) {
                continue;
            }
            if (selectedID.empty() ||
                (!_deviceID.empty() && _deviceID != "default" &&
                 _deviceID == identifier)) {
                selectedID = identifier;
            }
            if (!_deviceID.empty() && _deviceID == identifier) {
                break;
            }
        }
        if (selectedID.empty()) {
            reportFailure();
            return;
        }
        webrtc::VideoCaptureCapability requested;
        requested.videoType = webrtc::VideoType::kI420;
        requested.width = 640;
        requested.height = 480;
        requested.maxFPS = 15;
        webrtc::VideoCaptureCapability matched;
        std::vector<webrtc::VideoCaptureCapability> candidates;
        if (info->GetBestMatchedCapability(selectedID.c_str(), requested, matched) >= 0) {
            AppendCapabilityWithI420Fallback(candidates, matched);
        }
        const int capabilityCount = info->NumberOfCapabilities(selectedID.c_str());
        for (int capabilityIndex = 0; capabilityIndex < capabilityCount; ++capabilityIndex) {
            webrtc::VideoCaptureCapability capability;
            if (info->GetCapability(selectedID.c_str(), capabilityIndex, capability) == 0) {
                AppendCapabilityWithI420Fallback(candidates, capability);
            }
        }
        AppendCapability(candidates, requested);

        for (const webrtc::VideoCaptureCapability &candidate : candidates) {
            _module = webrtc::VideoCaptureFactory::Create(selectedID.c_str());
            if (!_module) {
                continue;
            }
            _module->RegisterCaptureDataCallback(this);
            if (_module->StartCapture(candidate) == 0) {
                return;
            }
            _module->DeRegisterCaptureDataCallback();
            _module = nullptr;
        }
        reportFailure();
    }

    void stopCapture() {
        if (!_module) {
            return;
        }
        _module->StopCapture();
        _module->DeRegisterCaptureDataCallback();
        _module = nullptr;
    }

    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _source;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _sink;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _uncroppedSink;
    rtc::scoped_refptr<webrtc::VideoCaptureModule> _module;
    std::string _deviceID;
    std::function<void(VideoState)> _stateUpdated;
    std::function<void()> _fatalError;
    VideoState _state = VideoState::Inactive;
    float _aspectRatio = 0.0f;
};

class VideoPlatform final : public PlatformInterface {
public:
    std::unique_ptr<webrtc::VideoEncoderFactory> makeVideoEncoderFactory(
            bool preferHardwareEncoding,
            bool isScreencast) override {
        (void)preferHardwareEncoding;
        (void)isScreencast;
        return webrtc::CreateBuiltinVideoEncoderFactory();
    }

    std::unique_ptr<webrtc::VideoDecoderFactory> makeVideoDecoderFactory() override {
        return webrtc::CreateBuiltinVideoDecoderFactory();
    }

    bool supportsEncoding(const std::string &codecName) override {
        return codecName == cricket::kVp8CodecName ||
            codecName == cricket::kH264CodecName;
    }

    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(
            rtc::Thread *signalingThread,
            rtc::Thread *workerThread) override {
        rtc::scoped_refptr<CameraTrackSource> source(
            new rtc::RefCountedObject<CameraTrackSource>());
        return webrtc::VideoTrackSourceProxy::Create(
            signalingThread,
            workerThread,
            source);
    }

    void adaptVideoSource(
            rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
            int width,
            int height,
            int fps) override {
        (void)source;
        (void)width;
        (void)height;
        (void)fps;
    }

    std::unique_ptr<VideoCapturerInterface> makeVideoCapturer(
            rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
            std::string deviceID,
            std::function<void(VideoState)> stateUpdated,
            std::function<void(PlatformCaptureInfo)> captureInfoUpdated,
            std::shared_ptr<PlatformContext> platformContext,
            std::pair<int, int> &outResolution) override {
        (void)captureInfoUpdated;
        (void)platformContext;
        return std::unique_ptr<VideoCapturerInterface>(
            new CameraCapturer(source, deviceID, std::move(stateUpdated), outResolution));
    }
};

} // namespace

std::unique_ptr<PlatformInterface> CreatePlatformInterface() {
    return std::unique_ptr<PlatformInterface>(new VideoPlatform());
}

} // namespace tgcalls
