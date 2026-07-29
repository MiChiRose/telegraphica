#include "platform/PlatformInterface.h"

#include "VideoCapturerInterface.h"
#include "api/video_codecs/builtin_video_decoder_factory.h"
#include "api/video_codecs/builtin_video_encoder_factory.h"

namespace tgcalls {
namespace {

class AudioOnlyPlatform final : public PlatformInterface {
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
        (void)codecName;
        return false;
    }

    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(
            rtc::Thread *signalingThread,
            rtc::Thread *workerThread) override {
        (void)signalingThread;
        (void)workerThread;
        return nullptr;
    }

    void adaptVideoSource(
            rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> videoSource,
            int width,
            int height,
            int fps) override {
        (void)videoSource;
        (void)width;
        (void)height;
        (void)fps;
    }

    std::unique_ptr<VideoCapturerInterface> makeVideoCapturer(
            rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source,
            std::string deviceId,
            std::function<void(VideoState)> stateUpdated,
            std::function<void(PlatformCaptureInfo)> captureInfoUpdated,
            std::shared_ptr<PlatformContext> platformContext,
            std::pair<int, int> &outResolution) override {
        (void)source;
        (void)deviceId;
        (void)stateUpdated;
        (void)captureInfoUpdated;
        (void)platformContext;
        outResolution = std::make_pair(0, 0);
        return nullptr;
    }
};

} // namespace

std::unique_ptr<PlatformInterface> CreatePlatformInterface() {
    return std::unique_ptr<PlatformInterface>(new AudioOnlyPlatform());
}

} // namespace tgcalls
