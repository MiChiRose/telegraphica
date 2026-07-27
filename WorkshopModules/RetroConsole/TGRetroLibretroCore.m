#import "TGRetroLibretroCore.h"
#import "TGRetroLibretroAPI.h"
#include <dlfcn.h>
#include <libkern/OSAtomic.h>

static TGRetroLibretroCore *TGRetroActiveCore = nil;

@interface TGRetroLibretroCore ()
- (BOOL)handleEnvironmentCommand:(unsigned)command data:(void *)data;
- (void)consumeVideoFrame:(const void *)data width:(unsigned)width height:(unsigned)height pitch:(size_t)pitch;
- (void)reportCoreMessage:(NSString *)message;
- (int16_t)inputStateForPort:(unsigned)port device:(unsigned)device identifier:(unsigned)identifier;
- (void)enqueueAudioSamples:(const int16_t *)samples frames:(size_t)frames;
- (BOOL)startAudioWithSampleRate:(double)sampleRate;
- (void)stopAudio;
- (OSStatus)renderAudioFrames:(UInt32)frameCount buffers:(AudioBufferList *)buffers;
@end

static bool TGRetroEnvironmentBridge(unsigned command, void *data) {
    return TGRetroActiveCore ? [TGRetroActiveCore handleEnvironmentCommand:command data:data] : false;
}

static void TGRetroVideoBridge(const void *data, unsigned width, unsigned height, size_t pitch) {
    [TGRetroActiveCore consumeVideoFrame:data width:width height:height pitch:pitch];
}

static void TGRetroAudioSampleBridge(int16_t left, int16_t right) {
    int16_t samples[2] = { left, right };
    [TGRetroActiveCore enqueueAudioSamples:samples frames:1];
}

static size_t TGRetroAudioBatchBridge(const int16_t *data, size_t frames) {
    [TGRetroActiveCore enqueueAudioSamples:data frames:frames];
    return frames;
}

static OSStatus TGRetroAudioRenderBridge(void *context,
                                         AudioUnitRenderActionFlags *flags,
                                         const AudioTimeStamp *timeStamp,
                                         UInt32 busNumber,
                                         UInt32 frameCount,
                                         AudioBufferList *buffers) {
    (void)flags;
    (void)timeStamp;
    (void)busNumber;
    return [(TGRetroLibretroCore *)context renderAudioFrames:frameCount buffers:buffers];
}

static void TGRetroInputPollBridge(void) {
}

static int16_t TGRetroInputStateBridge(unsigned port, unsigned device, unsigned index, unsigned identifier) {
    (void)index;
    return TGRetroActiveCore
        ? [TGRetroActiveCore inputStateForPort:port device:device identifier:identifier]
        : 0;
}

static NSError *TGRetroCoreError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"TGRetroConsoleError"
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:(message ? message : @"Retro core error.")
                                                                forKey:NSLocalizedDescriptionKey]];
}

static void *TGRetroRequiredSymbol(void *handle, const char *name, NSError **error) {
    void *symbol = dlsym(handle, name);
    if (!symbol && error) {
        *error = TGRetroCoreError(501, [NSString stringWithFormat:@"В ядре отсутствует функция %s.", name]);
    }
    return symbol;
}

@implementation TGRetroLibretroCore

@synthesize delegate = _delegate;
@synthesize gameLoaded = _gameLoaded;
@synthesize framesPerSecond = _framesPerSecond;

- (id)init {
    self = [super init];
    if (self) {
        _pixelFormat = TGRetroAPIPixelFormat0RGB1555;
        _framesPerSecond = 60.0;
    }
    return self;
}

- (BOOL)loadROMAtPath:(NSString *)ROMPath
             corePath:(NSString *)corePath
     supportDirectory:(NSString *)supportDirectory
                error:(NSError **)error {
    [self unload];
    if (![ROMPath length] || ![[NSFileManager defaultManager] fileExistsAtPath:ROMPath]) {
        if (error) *error = TGRetroCoreError(502, @"Файл картриджа не найден.");
        return NO;
    }
    if (![corePath length] || ![[NSFileManager defaultManager] fileExistsAtPath:corePath]) {
        if (error) *error = TGRetroCoreError(503, @"Ядро выбранной консоли не установлено.");
        return NO;
    }

    _libraryHandle = dlopen([corePath fileSystemRepresentation], RTLD_NOW | RTLD_LOCAL);
    if (!_libraryHandle) {
        if (error) {
            const char *description = dlerror();
            *error = TGRetroCoreError(504, [NSString stringWithFormat:@"Не удалось загрузить ядро: %s",
                                            description ? description : "unknown error"]);
        }
        return NO;
    }

#define TG_LOAD_CORE_SYMBOL(variable, name) \
    do { \
        variable = TGRetroRequiredSymbol(_libraryHandle, name, error); \
        if (!variable) { [self unload]; return NO; } \
    } while (0)
    TG_LOAD_CORE_SYMBOL(_retroSetEnvironment, "retro_set_environment");
    TG_LOAD_CORE_SYMBOL(_retroSetVideoRefresh, "retro_set_video_refresh");
    TG_LOAD_CORE_SYMBOL(_retroSetAudioSample, "retro_set_audio_sample");
    TG_LOAD_CORE_SYMBOL(_retroSetAudioSampleBatch, "retro_set_audio_sample_batch");
    TG_LOAD_CORE_SYMBOL(_retroSetInputPoll, "retro_set_input_poll");
    TG_LOAD_CORE_SYMBOL(_retroSetInputState, "retro_set_input_state");
    TG_LOAD_CORE_SYMBOL(_retroInit, "retro_init");
    TG_LOAD_CORE_SYMBOL(_retroDeinit, "retro_deinit");
    TG_LOAD_CORE_SYMBOL(_retroGetSystemInfo, "retro_get_system_info");
    TG_LOAD_CORE_SYMBOL(_retroGetSystemAVInfo, "retro_get_system_av_info");
    TG_LOAD_CORE_SYMBOL(_retroLoadGame, "retro_load_game");
    TG_LOAD_CORE_SYMBOL(_retroUnloadGame, "retro_unload_game");
    TG_LOAD_CORE_SYMBOL(_retroRun, "retro_run");
    TG_LOAD_CORE_SYMBOL(_retroReset, "retro_reset");
    TG_LOAD_CORE_SYMBOL(_retroSerializeSize, "retro_serialize_size");
    TG_LOAD_CORE_SYMBOL(_retroSerialize, "retro_serialize");
    TG_LOAD_CORE_SYMBOL(_retroUnserialize, "retro_unserialize");
#undef TG_LOAD_CORE_SYMBOL

    _ROMPath = [ROMPath copy];
    _supportDirectoryPath = [supportDirectory copy];
    [[NSFileManager defaultManager] createDirectoryAtPath:_supportDirectoryPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    _ROMData = [[NSData dataWithContentsOfFile:ROMPath options:NSDataReadingMappedIfSafe error:error] retain];
    if (!_ROMData) {
        [self unload];
        return NO;
    }

    TGRetroActiveCore = self;
    _retroSetEnvironment(TGRetroEnvironmentBridge);
    _retroSetVideoRefresh(TGRetroVideoBridge);
    _retroSetAudioSample(TGRetroAudioSampleBridge);
    _retroSetAudioSampleBatch(TGRetroAudioBatchBridge);
    _retroSetInputPoll(TGRetroInputPollBridge);
    _retroSetInputState(TGRetroInputStateBridge);
    _retroInit();

    TGRetroSystemInfo systemInfo;
    memset(&systemInfo, 0, sizeof(systemInfo));
    _retroGetSystemInfo(&systemInfo);
    TGRetroGameInfo gameInfo;
    memset(&gameInfo, 0, sizeof(gameInfo));
    gameInfo.path = [_ROMPath fileSystemRepresentation];
    if (!systemInfo.need_fullpath) {
        gameInfo.data = [_ROMData bytes];
        gameInfo.size = [_ROMData length];
    }
    if (!_retroLoadGame(&gameInfo)) {
        if (error) *error = TGRetroCoreError(505, @"Ядро не распознало этот файл картриджа.");
        [self unload];
        return NO;
    }
    _gameLoaded = YES;

    TGRetroSystemAVInfo AVInfo;
    memset(&AVInfo, 0, sizeof(AVInfo));
    _retroGetSystemAVInfo(&AVInfo);
    if (AVInfo.timing.fps >= 20.0 && AVInfo.timing.fps <= 240.0) {
        _framesPerSecond = AVInfo.timing.fps;
    }
    if (AVInfo.timing.sample_rate >= 8000.0 && AVInfo.timing.sample_rate <= 192000.0) {
        [self startAudioWithSampleRate:AVInfo.timing.sample_rate];
    }
    return YES;
}

- (void)enqueueAudioSamples:(const int16_t *)samples frames:(size_t)frames {
    if (!samples || !_audioRing || frames == 0) return;
    size_t index = 0;
    for (index = 0; index < frames; index++) {
        int64_t writeFrame = _audioWriteFrame;
        int64_t readFrame = _audioReadFrame;
        if (writeFrame - readFrame >= TGRetroAudioRingFrames) {
            OSAtomicCompareAndSwap64Barrier(readFrame,
                                             writeFrame - TGRetroAudioRingFrames + 1,
                                             &_audioReadFrame);
        }
        NSUInteger slot = (NSUInteger)(writeFrame % TGRetroAudioRingFrames) * 2;
        _audioRing[slot] = samples[index * 2];
        _audioRing[slot + 1] = samples[index * 2 + 1];
        OSAtomicIncrement64Barrier(&_audioWriteFrame);
    }
}

- (BOOL)startAudioWithSampleRate:(double)sampleRate {
    [self stopAudio];
    _audioRing = calloc(TGRetroAudioRingFrames * 2, sizeof(int16_t));
    if (!_audioRing) return NO;

    AudioComponentDescription description;
    memset(&description, 0, sizeof(description));
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_DefaultOutput;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    if (!component || AudioComponentInstanceNew(component, &_audioUnit) != noErr) {
        [self stopAudio];
        return NO;
    }

    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBytesPerPacket = 4;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = 4;
    format.mChannelsPerFrame = 2;
    format.mBitsPerChannel = 16;
    if (AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &format,
                             sizeof(format)) != noErr) {
        [self stopAudio];
        return NO;
    }

    AURenderCallbackStruct callback;
    callback.inputProc = TGRetroAudioRenderBridge;
    callback.inputProcRefCon = self;
    if (AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             0,
                             &callback,
                             sizeof(callback)) != noErr ||
        AudioUnitInitialize(_audioUnit) != noErr ||
        AudioOutputUnitStart(_audioUnit) != noErr) {
        [self stopAudio];
        return NO;
    }
    return YES;
}

- (OSStatus)renderAudioFrames:(UInt32)frameCount buffers:(AudioBufferList *)buffers {
    if (!buffers) return noErr;
    UInt32 bufferIndex = 0;
    for (bufferIndex = 0; bufferIndex < buffers->mNumberBuffers; bufferIndex++) {
        memset(buffers->mBuffers[bufferIndex].mData, 0, buffers->mBuffers[bufferIndex].mDataByteSize);
    }
    if (!_audioRing || buffers->mNumberBuffers == 0) return noErr;

    AudioBuffer *output = &buffers->mBuffers[0];
    int16_t *samples = (int16_t *)output->mData;
    UInt32 writableFrames = MIN(frameCount, output->mDataByteSize / 4);
    UInt32 frame = 0;
    for (frame = 0; frame < writableFrames; frame++) {
        int64_t readFrame = _audioReadFrame;
        if (readFrame >= _audioWriteFrame) break;
        NSUInteger slot = (NSUInteger)(readFrame % TGRetroAudioRingFrames) * 2;
        samples[frame * 2] = _audioRing[slot];
        samples[frame * 2 + 1] = _audioRing[slot + 1];
        OSAtomicIncrement64Barrier(&_audioReadFrame);
    }
    return noErr;
}

- (void)stopAudio {
    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
        AudioUnitUninitialize(_audioUnit);
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
    }
    if (_audioRing) {
        free(_audioRing);
        _audioRing = NULL;
    }
    _audioReadFrame = 0;
    _audioWriteFrame = 0;
}

- (BOOL)handleEnvironmentCommand:(unsigned)command data:(void *)data {
    switch (command) {
        case TGRetroAPIEnvironmentGetCanDupe:
            if (data) *((bool *)data) = true;
            return true;
        case TGRetroAPIEnvironmentSetPixelFormat:
            if (data) {
                unsigned format = *((unsigned *)data);
                if (format <= TGRetroAPIPixelFormatXRGB8888) {
                    _pixelFormat = (NSInteger)format;
                    return true;
                }
            }
            return false;
        case TGRetroAPIEnvironmentGetSystemDirectory:
        case TGRetroAPIEnvironmentGetSaveDirectory:
            if (data) {
                *((const char **)data) = [_supportDirectoryPath fileSystemRepresentation];
                return true;
            }
            return false;
        case TGRetroAPIEnvironmentSetMessage:
            if (data) {
                TGRetroMessage *message = (TGRetroMessage *)data;
                if (message->msg) {
                    [self reportCoreMessage:[NSString stringWithUTF8String:message->msg]];
                }
            }
            return true;
        case TGRetroAPIEnvironmentGetVariable:
            if (data) ((TGRetroVariable *)data)->value = NULL;
            return false;
        case TGRetroAPIEnvironmentGetVariableUpdate:
            if (data) *((bool *)data) = false;
            return true;
        case TGRetroAPIEnvironmentGetLanguage:
            if (data) *((unsigned *)data) = 0;
            return true;
        case TGRetroAPIEnvironmentGetCoreOptionsVersion:
            if (data) *((unsigned *)data) = 0;
            return true;
        case TGRetroAPIEnvironmentSetVariables:
        case TGRetroAPIEnvironmentSetInputDescriptors:
        case TGRetroAPIEnvironmentSetControllerInfo:
        case TGRetroAPIEnvironmentSetCoreOptions:
        case TGRetroAPIEnvironmentSetCoreOptionsInternational:
        case TGRetroAPIEnvironmentSetContentInfoOverride:
        case TGRetroAPIEnvironmentSetCoreOptionsV2:
        case TGRetroAPIEnvironmentSetCoreOptionsV2International:
            return true;
        default:
            return false;
    }
}

- (void)consumeVideoFrame:(const void *)data width:(unsigned)width height:(unsigned)height pitch:(size_t)pitch {
    if (!data || width == 0 || height == 0) return;
    NSUInteger outputLength = (NSUInteger)width * (NSUInteger)height * 4;
    if (!_convertedFrameData || [_convertedFrameData length] != outputLength) {
        [_convertedFrameData release];
        _convertedFrameData = [[NSMutableData alloc] initWithLength:outputLength];
    }
    uint8_t *destination = [_convertedFrameData mutableBytes];
    NSUInteger row = 0;
    for (row = 0; row < height; row++) {
        const uint8_t *sourceRow = ((const uint8_t *)data) + row * pitch;
        NSUInteger column = 0;
        for (column = 0; column < width; column++) {
            uint8_t red = 0;
            uint8_t green = 0;
            uint8_t blue = 0;
            if (_pixelFormat == TGRetroAPIPixelFormatXRGB8888) {
                uint32_t pixel = ((const uint32_t *)sourceRow)[column];
                red = (uint8_t)((pixel >> 16) & 0xff);
                green = (uint8_t)((pixel >> 8) & 0xff);
                blue = (uint8_t)(pixel & 0xff);
            } else {
                uint16_t pixel = ((const uint16_t *)sourceRow)[column];
                if (_pixelFormat == TGRetroAPIPixelFormatRGB565) {
                    red = (uint8_t)(((pixel >> 11) & 0x1f) * 255 / 31);
                    green = (uint8_t)(((pixel >> 5) & 0x3f) * 255 / 63);
                    blue = (uint8_t)((pixel & 0x1f) * 255 / 31);
                } else {
                    red = (uint8_t)(((pixel >> 10) & 0x1f) * 255 / 31);
                    green = (uint8_t)(((pixel >> 5) & 0x1f) * 255 / 31);
                    blue = (uint8_t)((pixel & 0x1f) * 255 / 31);
                }
            }
            NSUInteger offset = (row * (NSUInteger)width + column) * 4;
            destination[offset] = blue;
            destination[offset + 1] = green;
            destination[offset + 2] = red;
            destination[offset + 3] = 255;
        }
    }
    if ([_delegate respondsToSelector:@selector(retroCore:didProduceFrame:width:height:)]) {
        [_delegate retroCore:self
             didProduceFrame:_convertedFrameData
                       width:width
                      height:height];
    }
}

- (void)reportCoreMessage:(NSString *)message {
    if ([_delegate respondsToSelector:@selector(retroCore:didReportMessage:)]) {
        [_delegate retroCore:self didReportMessage:message];
    }
}

- (int16_t)inputStateForPort:(unsigned)port device:(unsigned)device identifier:(unsigned)identifier {
    if (port != 0 || device != TGRetroAPIDeviceJoypad || identifier >= 16) return 0;
    return _buttonStates[identifier] ? 1 : 0;
}

- (void)runFrame {
    if (_gameLoaded && _retroRun) {
        TGRetroActiveCore = self;
        _retroRun();
    }
}

- (void)reset {
    if (_gameLoaded && _retroReset) _retroReset();
}

- (void)setJoypadButton:(NSUInteger)button pressed:(BOOL)pressed {
    if (button < 16) _buttonStates[button] = pressed;
}

- (NSData *)serializedState {
    if (!_gameLoaded || !_retroSerializeSize || !_retroSerialize) return nil;
    size_t size = _retroSerializeSize();
    if (size == 0 || size > 32 * 1024 * 1024) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    return _retroSerialize([data mutableBytes], size) ? data : nil;
}

- (BOOL)restoreSerializedState:(NSData *)state {
    return (_gameLoaded && [state length] > 0 && _retroUnserialize)
        ? _retroUnserialize([state bytes], [state length])
        : NO;
}

- (void)unload {
    [self stopAudio];
    if (_gameLoaded && _retroUnloadGame) {
        _retroUnloadGame();
    }
    _gameLoaded = NO;
    if (_retroDeinit) {
        _retroDeinit();
    }
    if (_libraryHandle) {
        dlclose(_libraryHandle);
        _libraryHandle = NULL;
    }
    if (TGRetroActiveCore == self) TGRetroActiveCore = nil;
    [_ROMData release];
    _ROMData = nil;
    [_ROMPath release];
    _ROMPath = nil;
    [_supportDirectoryPath release];
    _supportDirectoryPath = nil;
    memset(_buttonStates, 0, sizeof(_buttonStates));
    _retroSetEnvironment = NULL;
    _retroSetVideoRefresh = NULL;
    _retroSetAudioSample = NULL;
    _retroSetAudioSampleBatch = NULL;
    _retroSetInputPoll = NULL;
    _retroSetInputState = NULL;
    _retroInit = NULL;
    _retroDeinit = NULL;
    _retroGetSystemInfo = NULL;
    _retroGetSystemAVInfo = NULL;
    _retroLoadGame = NULL;
    _retroUnloadGame = NULL;
    _retroRun = NULL;
    _retroReset = NULL;
    _retroSerializeSize = NULL;
    _retroSerialize = NULL;
    _retroUnserialize = NULL;
}

- (void)dealloc {
    [self unload];
    [_convertedFrameData release];
    [super dealloc];
}

@end
