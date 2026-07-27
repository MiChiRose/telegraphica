#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>
#import "TGRetroLibretroAPI.h"

#define TGRetroAudioRingFrames 32768

@class TGRetroLibretroCore;

@protocol TGRetroLibretroCoreDelegate <NSObject>
- (void)retroCore:(TGRetroLibretroCore *)core
 didProduceFrame:(NSData *)frameData
            width:(NSUInteger)width
           height:(NSUInteger)height;
- (void)retroCore:(TGRetroLibretroCore *)core didReportMessage:(NSString *)message;
@end

@interface TGRetroLibretroCore : NSObject {
@private
    id<TGRetroLibretroCoreDelegate> _delegate;
    void *_libraryHandle;
    NSData *_ROMData;
    NSString *_ROMPath;
    NSString *_supportDirectoryPath;
    NSMutableData *_convertedFrameData;
    NSInteger _pixelFormat;
    BOOL _gameLoaded;
    BOOL _buttonStates[16];
    double _framesPerSecond;
    AudioComponentInstance _audioUnit;
    int16_t *_audioRing;
    volatile int64_t _audioReadFrame;
    volatile int64_t _audioWriteFrame;

    void (*_retroSetEnvironment)(TGRetroEnvironmentCallback);
    void (*_retroSetVideoRefresh)(TGRetroVideoCallback);
    void (*_retroSetAudioSample)(TGRetroAudioSampleCallback);
    void (*_retroSetAudioSampleBatch)(TGRetroAudioBatchCallback);
    void (*_retroSetInputPoll)(TGRetroInputPollCallback);
    void (*_retroSetInputState)(TGRetroInputStateCallback);
    void (*_retroInit)(void);
    void (*_retroDeinit)(void);
    void (*_retroGetSystemInfo)(TGRetroSystemInfo *);
    void (*_retroGetSystemAVInfo)(TGRetroSystemAVInfo *);
    bool (*_retroLoadGame)(const TGRetroGameInfo *);
    void (*_retroUnloadGame)(void);
    void (*_retroRun)(void);
    void (*_retroReset)(void);
    size_t (*_retroSerializeSize)(void);
    bool (*_retroSerialize)(void *, size_t);
    bool (*_retroUnserialize)(const void *, size_t);
}

@property(nonatomic, assign) id<TGRetroLibretroCoreDelegate> delegate;
@property(nonatomic, assign, readonly) BOOL gameLoaded;
@property(nonatomic, assign, readonly) double framesPerSecond;

- (BOOL)loadROMAtPath:(NSString *)ROMPath
             corePath:(NSString *)corePath
     supportDirectory:(NSString *)supportDirectory
                error:(NSError **)error;
- (void)runFrame;
- (void)reset;
- (void)unload;
- (void)setJoypadButton:(NSUInteger)button pressed:(BOOL)pressed;
- (NSData *)serializedState;
- (BOOL)restoreSerializedState:(NSData *)state;

@end
