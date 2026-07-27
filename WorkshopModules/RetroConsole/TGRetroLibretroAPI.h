#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

enum {
    TGRetroAPIEnvironmentGetCanDupe = 3,
    TGRetroAPIEnvironmentSetMessage = 6,
    TGRetroAPIEnvironmentGetSystemDirectory = 9,
    TGRetroAPIEnvironmentSetPixelFormat = 10,
    TGRetroAPIEnvironmentSetInputDescriptors = 11,
    TGRetroAPIEnvironmentGetVariable = 15,
    TGRetroAPIEnvironmentSetVariables = 16,
    TGRetroAPIEnvironmentGetVariableUpdate = 17,
    TGRetroAPIEnvironmentGetSaveDirectory = 31,
    TGRetroAPIEnvironmentSetControllerInfo = 35,
    TGRetroAPIEnvironmentGetLanguage = 39,
    TGRetroAPIEnvironmentGetCoreOptionsVersion = 52,
    TGRetroAPIEnvironmentSetCoreOptions = 53,
    TGRetroAPIEnvironmentSetCoreOptionsInternational = 54,
    TGRetroAPIEnvironmentSetContentInfoOverride = 65,
    TGRetroAPIEnvironmentSetCoreOptionsV2 = 67,
    TGRetroAPIEnvironmentSetCoreOptionsV2International = 68
};

enum {
    TGRetroAPIPixelFormat0RGB1555 = 0,
    TGRetroAPIPixelFormatRGB565 = 1,
    TGRetroAPIPixelFormatXRGB8888 = 2
};

enum {
    TGRetroAPIDeviceJoypad = 1,
    TGRetroAPIJoypadB = 0,
    TGRetroAPIJoypadY = 1,
    TGRetroAPIJoypadSelect = 2,
    TGRetroAPIJoypadStart = 3,
    TGRetroAPIJoypadUp = 4,
    TGRetroAPIJoypadDown = 5,
    TGRetroAPIJoypadLeft = 6,
    TGRetroAPIJoypadRight = 7,
    TGRetroAPIJoypadA = 8,
    TGRetroAPIJoypadX = 9,
    TGRetroAPIJoypadL = 10,
    TGRetroAPIJoypadR = 11
};

typedef bool (*TGRetroEnvironmentCallback)(unsigned command, void *data);
typedef void (*TGRetroVideoCallback)(const void *data, unsigned width, unsigned height, size_t pitch);
typedef void (*TGRetroAudioSampleCallback)(int16_t left, int16_t right);
typedef size_t (*TGRetroAudioBatchCallback)(const int16_t *data, size_t frames);
typedef void (*TGRetroInputPollCallback)(void);
typedef int16_t (*TGRetroInputStateCallback)(unsigned port, unsigned device, unsigned index, unsigned identifier);

typedef struct {
    const char *path;
    const void *data;
    size_t size;
    const char *meta;
} TGRetroGameInfo;

typedef struct {
    const char *library_name;
    const char *library_version;
    const char *valid_extensions;
    bool need_fullpath;
    bool block_extract;
} TGRetroSystemInfo;

typedef struct {
    unsigned base_width;
    unsigned base_height;
    unsigned max_width;
    unsigned max_height;
    float aspect_ratio;
} TGRetroGameGeometry;

typedef struct {
    double fps;
    double sample_rate;
} TGRetroSystemTiming;

typedef struct {
    TGRetroGameGeometry geometry;
    TGRetroSystemTiming timing;
} TGRetroSystemAVInfo;

typedef struct {
    const char *key;
    const char *value;
} TGRetroVariable;

typedef struct {
    const char *msg;
    unsigned frames;
} TGRetroMessage;

