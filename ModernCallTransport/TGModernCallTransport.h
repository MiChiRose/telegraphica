#ifndef TGModernCallTransport_h
#define TGModernCallTransport_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TG_MODERN_CALL_TRANSPORT_ABI_VERSION 2

typedef void (*TGModernCallStateCallback)(void *context, int state);
typedef void (*TGModernCallSignalBarsCallback)(void *context, int signalBars);
typedef void (*TGModernCallSignalingDataCallback)(void *context,
                                                   const uint8_t *bytes,
                                                   size_t length);
typedef void (*TGModernCallLogCallback)(void *context, const char *message);
typedef void (*TGModernCallVideoFrameCallback)(void *context,
                                                int local,
                                                const uint8_t *argbBytes,
                                                size_t length,
                                                int width,
                                                int height,
                                                int bytesPerRow);
typedef void (*TGModernCallRemoteVideoStateCallback)(void *context, int state);

typedef struct TGModernCallCallbacks {
    TGModernCallStateCallback stateChanged;
    TGModernCallSignalBarsCallback signalBarsChanged;
    TGModernCallSignalingDataCallback signalingDataEmitted;
    TGModernCallLogCallback logMessage;
    TGModernCallVideoFrameCallback videoFrame;
    TGModernCallRemoteVideoStateCallback remoteVideoStateChanged;
} TGModernCallCallbacks;

int TGModernCallTransportABIVersion(void);
const char *TGModernCallTransportVersions(void);
int TGModernCallTransportMaxLayer(void);

void *TGModernCallTransportCreate(const char *callJSON,
                                  TGModernCallCallbacks callbacks,
                                  void *context,
                                  char *errorBuffer,
                                  size_t errorBufferLength);
void TGModernCallTransportReceiveSignalingData(void *transport,
                                               const uint8_t *bytes,
                                               size_t length);
void TGModernCallTransportSetMicrophoneMuted(void *transport, int muted);
void TGModernCallTransportSetSpeakerMuted(void *transport, int muted);
void TGModernCallTransportSetCameraEnabled(void *transport, int enabled);
int64_t TGModernCallTransportPreferredRelayID(void *transport);
void TGModernCallTransportStop(void *transport);

#ifdef __cplusplus
}
#endif

#endif
