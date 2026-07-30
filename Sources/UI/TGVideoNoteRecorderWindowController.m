#import "TGVideoNoteRecorderWindowController.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import "TGLocalization.h"
#import "TGIconAssets.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"
#include <math.h>

static NSTimeInterval const TGVideoNoteMaximumDuration = 60.0;

@interface TGVideoNotePreviewView : NSView
@end

@implementation TGVideoNotePreviewView

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor blackColor] setFill];
    NSRectFill([self bounds]);
}

@end

@interface TGVideoNoteRecorderWindowController () <AVCaptureFileOutputRecordingDelegate, NSWindowDelegate>
@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *cameraPreviewLayer;
@property (nonatomic, retain) AVAssetExportSession *exportSession;
@property (nonatomic, retain) AVPlayer *previewPlayer;
@property (nonatomic, retain) AVPlayerLayer *playerLayer;
@property (nonatomic, retain) TGVideoNotePreviewView *previewView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextField *timerField;
@property (nonatomic, retain) NSImageView *cameraStateImageView;
@property (nonatomic, retain) NSButton *recordButton;
@property (nonatomic, retain) NSButton *stopButton;
@property (nonatomic, retain) NSButton *playButton;
@property (nonatomic, retain) NSButton *retryButton;
@property (nonatomic, retain) NSButton *cancelButton;
@property (nonatomic, retain) NSButton *sendButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSTimer *recordingTimer;
@property (nonatomic, retain) NSDate *recordingStartDate;
@property (nonatomic, copy) NSString *recordingPath;
@property (nonatomic, copy) NSString *preparedPath;
@property (nonatomic, assign) BOOL microphoneEnabled;
@property (nonatomic, assign) BOOL preparing;
@property (nonatomic, assign) BOOL cancelling;
@end

@implementation TGVideoNoteRecorderWindowController

@synthesize delegate = _delegate;
@synthesize captureSession = _captureSession;
@synthesize movieOutput = _movieOutput;
@synthesize cameraPreviewLayer = _cameraPreviewLayer;
@synthesize exportSession = _exportSession;
@synthesize previewPlayer = _previewPlayer;
@synthesize playerLayer = _playerLayer;
@synthesize previewView = _previewView;
@synthesize statusField = _statusField;
@synthesize timerField = _timerField;
@synthesize cameraStateImageView = _cameraStateImageView;
@synthesize recordButton = _recordButton;
@synthesize stopButton = _stopButton;
@synthesize playButton = _playButton;
@synthesize retryButton = _retryButton;
@synthesize cancelButton = _cancelButton;
@synthesize sendButton = _sendButton;
@synthesize spinner = _spinner;
@synthesize recordingTimer = _recordingTimer;
@synthesize recordingStartDate = _recordingStartDate;
@synthesize recordingPath = _recordingPath;
@synthesize preparedPath = _preparedPath;
@synthesize microphoneEnabled = _microphoneEnabled;
@synthesize preparing = _preparing;
@synthesize cancelling = _cancelling;

- (id)init {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 540.0, 650.0)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        [window setTitle:TGLoc(@"videoNote.window.title")];
        [window setReleasedWhenClosed:NO];
        [window setDelegate:self];
        [self buildViews];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame
                            font:(NSFont *)font
                           color:(NSColor *)color
                       alignment:(NSTextAlignment)alignment {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:color];
    [field setAlignment:alignment];
    return field;
}

- (NSButton *)buttonWithFrame:(NSRect)frame
                         title:(NSString *)title
                        action:(SEL)action
                       primary:(BOOL)primary {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    NSButtonCell *cell = primary
        ? (NSButtonCell *)[[[TGPrimaryTextButtonCell alloc] initTextCell:title] autorelease]
        : (NSButtonCell *)[[[TGSecondaryTextButtonCell alloc] initTextCell:title] autorelease];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(28.0, 606.0, 484.0, 28.0)
                                         font:[NSFont boldSystemFontOfSize:21.0]
                                        color:TGClassicHeaderTextColor(1.0)
                                    alignment:NSCenterTextAlignment];
    [title setStringValue:TGLoc(@"videoNote.title")];
    [root addSubview:title];
    self.cameraStateImageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(490.0, 608.0, 24.0, 24.0)] autorelease];
    [self.cameraStateImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self.cameraStateImageView setImage:TGTemplateIconAssetImage(@"video",
                                                                 NSMakeSize(24.0, 24.0),
                                                                 TGClassicHeaderTextColor(1.0),
                                                                 1.0)];
    [root addSubview:self.cameraStateImageView];

    NSTextField *hint = [self labelWithFrame:NSMakeRect(28.0, 580.0, 484.0, 22.0)
                                        font:[NSFont systemFontOfSize:11.0]
                                       color:TGClassicHeaderDetailTextColor(0.9)
                                   alignment:NSCenterTextAlignment];
    [hint setStringValue:TGLoc(@"videoNote.hint")];
    [root addSubview:hint];

    TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(48.0, 128.0, 444.0, 440.0)] autorelease];
    [root addSubview:card];

    self.previewView = [[[TGVideoNotePreviewView alloc] initWithFrame:NSMakeRect(90.0, 184.0, 360.0, 360.0)] autorelease];
    [self.previewView setWantsLayer:YES];
    [[self.previewView layer] setCornerRadius:180.0];
    [[self.previewView layer] setMasksToBounds:YES];
    [root addSubview:self.previewView];

    self.statusField = [self labelWithFrame:NSMakeRect(72.0, 150.0, 396.0, 22.0)
                                       font:[NSFont systemFontOfSize:12.0]
                                      color:TGClassicCardMutedInkColor()
                                  alignment:NSCenterTextAlignment];
    [root addSubview:self.statusField];

    self.timerField = [self labelWithFrame:NSMakeRect(208.0, 510.0, 124.0, 24.0)
                                      font:[NSFont boldSystemFontOfSize:16.0]
                                     color:[NSColor whiteColor]
                                 alignment:NSCenterTextAlignment];
    [self.timerField setStringValue:@"0:00 / 1:00"];
    [self.timerField setHidden:YES];
    [root addSubview:self.timerField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(258.0, 154.0, 16.0, 16.0)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [root addSubview:self.spinner];

    self.cancelButton = [self buttonWithFrame:NSMakeRect(48.0, 72.0, 112.0, 34.0)
                                         title:TGLoc(@"cancel")
                                        action:@selector(cancelPressed:)
                                       primary:NO];
    [root addSubview:self.cancelButton];
    self.retryButton = [self buttonWithFrame:NSMakeRect(168.0, 72.0, 112.0, 34.0)
                                        title:TGLoc(@"videoNote.retry")
                                       action:@selector(retryPressed:)
                                      primary:NO];
    [root addSubview:self.retryButton];
    self.playButton = [self buttonWithFrame:NSMakeRect(288.0, 72.0, 88.0, 34.0)
                                       title:TGLoc(@"play")
                                      action:@selector(playPressed:)
                                     primary:NO];
    [root addSubview:self.playButton];
    self.recordButton = [self buttonWithFrame:NSMakeRect(384.0, 72.0, 108.0, 34.0)
                                         title:TGLoc(@"videoNote.record")
                                        action:@selector(recordPressed:)
                                       primary:YES];
    [root addSubview:self.recordButton];
    self.stopButton = [self buttonWithFrame:NSMakeRect(384.0, 72.0, 108.0, 34.0)
                                       title:TGLoc(@"videoNote.stop")
                                      action:@selector(stopPressed:)
                                     primary:YES];
    [root addSubview:self.stopButton];
    self.sendButton = [self buttonWithFrame:NSMakeRect(384.0, 72.0, 108.0, 34.0)
                                       title:TGLoc(@"send")
                                      action:@selector(sendPressed:)
                                     primary:YES];
    [root addSubview:self.sendButton];
    [self showReadyToRecordControls];
}

- (NSString *)temporaryPathWithExtension:(NSString *)extension {
    NSString *name = [NSString stringWithFormat:@"telegraphica-video-note-%lld-%u.%@",
                      (long long)([[NSDate date] timeIntervalSince1970] * 1000.0),
                      arc4random(),
                      extension];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (void)removeFileAtPath:(NSString *)path {
    if ([path length] > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (void)showReadyToRecordControls {
    [self.recordButton setHidden:NO];
    [self.stopButton setHidden:YES];
    [self.playButton setHidden:YES];
    [self.retryButton setHidden:YES];
    [self.sendButton setHidden:YES];
    [self.timerField setHidden:YES];
    [self.statusField setStringValue:TGLoc(@"videoNote.ready")];
}

- (void)showRecordingControls {
    [self.recordButton setHidden:YES];
    [self.stopButton setHidden:NO];
    [self.playButton setHidden:YES];
    [self.retryButton setHidden:YES];
    [self.sendButton setHidden:YES];
    [self.timerField setHidden:NO];
    [self.statusField setStringValue:(self.microphoneEnabled
        ? TGLoc(@"videoNote.recording")
        : TGLoc(@"videoNote.recordingSilent"))];
}

- (void)showPreparingControls {
    self.preparing = YES;
    [self.recordButton setHidden:YES];
    [self.stopButton setHidden:YES];
    [self.playButton setHidden:YES];
    [self.retryButton setHidden:YES];
    [self.sendButton setHidden:YES];
    [self.timerField setHidden:YES];
    [self.statusField setStringValue:TGLoc(@"videoNote.preparing")];
    [self.spinner startAnimation:nil];
}

- (void)showPreviewControls {
    self.preparing = NO;
    [self.spinner stopAnimation:nil];
    [self.recordButton setHidden:YES];
    [self.stopButton setHidden:YES];
    [self.playButton setHidden:NO];
    [self.retryButton setHidden:NO];
    [self.sendButton setHidden:NO];
    [self.timerField setHidden:YES];
    [self.statusField setStringValue:TGLoc(@"videoNote.preview")];
}

- (void)showError:(NSString *)message {
    self.preparing = NO;
    [self.spinner stopAnimation:nil];
    [self showReadyToRecordControls];
    [self.statusField setStringValue:([message length] > 0 ? message : TGLoc(@"videoNote.failed"))];
    [self.cameraStateImageView setImage:TGTemplateIconAssetImage(@"video-off",
                                                                 NSMakeSize(24.0, 24.0),
                                                                 TGClassicHeaderTextColor(1.0),
                                                                 1.0)];
}

- (void)attachCameraPreviewLayer {
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    if (!self.cameraPreviewLayer) {
        AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        [layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        self.cameraPreviewLayer = layer;
    }
    [self.cameraPreviewLayer setFrame:[[self.previewView layer] bounds]];
    [[self.previewView layer] addSublayer:self.cameraPreviewLayer];
}

- (BOOL)configureCaptureSession {
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!camera) {
        [self showError:TGLoc(@"videoNote.noCamera")];
        [self.recordButton setEnabled:NO];
        return NO;
    }

    AVCaptureSession *session = [[[AVCaptureSession alloc] init] autorelease];
    if ([session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    }
    NSError *inputError = nil;
    AVCaptureDeviceInput *cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&inputError];
    if (!cameraInput || ![session canAddInput:cameraInput]) {
        [self showError:([inputError localizedDescription] ?: TGLoc(@"videoNote.noCamera"))];
        [self.recordButton setEnabled:NO];
        return NO;
    }
    [session addInput:cameraInput];

    if (self.microphoneEnabled) {
        AVCaptureDevice *microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        NSError *audioError = nil;
        AVCaptureDeviceInput *audioInput = microphone
            ? [AVCaptureDeviceInput deviceInputWithDevice:microphone error:&audioError]
            : nil;
        if (audioInput && [session canAddInput:audioInput]) {
            [session addInput:audioInput];
        } else {
            self.microphoneEnabled = NO;
        }
    }

    AVCaptureMovieFileOutput *output = [[[AVCaptureMovieFileOutput alloc] init] autorelease];
    if (![session canAddOutput:output]) {
        [self showError:TGLoc(@"videoNote.failed")];
        [self.recordButton setEnabled:NO];
        return NO;
    }
    [session addOutput:output];
    [output setMaxRecordedDuration:CMTimeMakeWithSeconds(TGVideoNoteMaximumDuration, 600)];
    self.captureSession = session;
    self.movieOutput = output;
    [self attachCameraPreviewLayer];
    return YES;
}

- (void)presentWithMicrophoneEnabled:(BOOL)microphoneEnabled {
    self.cancelling = NO;
    self.microphoneEnabled = microphoneEnabled;
    [self.cameraStateImageView setImage:TGTemplateIconAssetImage(@"video",
                                                                 NSMakeSize(24.0, 24.0),
                                                                 TGClassicHeaderTextColor(1.0),
                                                                 1.0)];
    [self.recordButton setEnabled:YES];
    [self removeFileAtPath:self.recordingPath];
    [self removeFileAtPath:self.preparedPath];
    self.recordingPath = nil;
    self.preparedPath = nil;
    [self.previewPlayer pause];
    self.previewPlayer = nil;
    [self showReadyToRecordControls];
    if (![self configureCaptureSession]) {
        [[self window] center];
        [[self window] makeKeyAndOrderFront:nil];
        return;
    }
    [[self window] center];
    [[self window] makeKeyAndOrderFront:nil];
    AVCaptureSession *session = [self.captureSession retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [session startRunning];
        [session release];
    });
}

- (void)recordPressed:(id)sender {
    (void)sender;
    if (!self.movieOutput || [self.movieOutput isRecording] || self.preparing) {
        return;
    }
    [self.previewPlayer pause];
    self.previewPlayer = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    [self attachCameraPreviewLayer];
    [self removeFileAtPath:self.recordingPath];
    [self removeFileAtPath:self.preparedPath];
    self.preparedPath = nil;
    self.recordingPath = [self temporaryPathWithExtension:@"mov"];
    self.recordingStartDate = [NSDate date];
    [self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:self.recordingPath]
                                  recordingDelegate:self];
    [self showRecordingControls];
    [self.recordingTimer invalidate];
    self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                           target:self
                                                         selector:@selector(recordingTimerDidFire:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)recordingTimerDidFire:(NSTimer *)timer {
    (void)timer;
    NSTimeInterval duration = self.recordingStartDate
        ? [[NSDate date] timeIntervalSinceDate:self.recordingStartDate]
        : 0.0;
    NSInteger seconds = MIN((NSInteger)floor(duration), (NSInteger)TGVideoNoteMaximumDuration);
    [self.timerField setStringValue:[NSString stringWithFormat:@"0:%02ld / 1:00", (long)seconds]];
    if (duration >= TGVideoNoteMaximumDuration && [self.movieOutput isRecording]) {
        [self.movieOutput stopRecording];
    }
}

- (void)stopPressed:(id)sender {
    (void)sender;
    if ([self.movieOutput isRecording]) {
        [self.movieOutput stopRecording];
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)output
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections
                error:(NSError *)error {
    (void)output;
    (void)connections;
    NSString *path = [[outputFileURL path] copy];
    NSString *errorDescription = [[error localizedDescription] copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.recordingTimer invalidate];
        self.recordingTimer = nil;
        if (self.cancelling) {
            [self removeFileAtPath:path];
        } else if (error && ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [self showError:errorDescription];
        } else {
            self.recordingPath = path;
            [self prepareSquareVideoAtPath:path];
        }
        [errorDescription release];
        [path release];
    });
}

- (void)prepareSquareVideoAtPath:(NSString *)sourcePath {
    [self showPreparingControls];
    [self.captureSession stopRunning];
    [self.cameraPreviewLayer removeFromSuperlayer];

    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:sourcePath]];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        [self showError:TGLoc(@"videoNote.failed")];
        return;
    }
    CGSize naturalSize = [videoTrack naturalSize];
    CGFloat shortestSide = MIN(fabs(naturalSize.width), fabs(naturalSize.height));
    if (shortestSide < 1.0) {
        [self showError:TGLoc(@"videoNote.failed")];
        return;
    }
    CGFloat outputSide = MIN(640.0, shortestSide);
    CGFloat scale = outputSide / shortestSide;
    CGFloat translatedX = (outputSide - fabs(naturalSize.width) * scale) * 0.5;
    CGFloat translatedY = (outputSide - fabs(naturalSize.height) * scale) * 0.5;

    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    [videoComposition setRenderSize:CGSizeMake(outputSide, outputSide)];
    [videoComposition setFrameDuration:CMTimeMake(1, 30)];
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    [instruction setTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration])];
    AVMutableVideoCompositionLayerInstruction *layerInstruction =
        [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    transform.tx = translatedX;
    transform.ty = translatedY;
    [layerInstruction setTransform:transform atTime:kCMTimeZero];
    [instruction setLayerInstructions:[NSArray arrayWithObject:layerInstruction]];
    [videoComposition setInstructions:[NSArray arrayWithObject:instruction]];

    NSString *destination = [self temporaryPathWithExtension:@"mp4"];
    [self removeFileAtPath:destination];
    AVAssetExportSession *exporter = [[[AVAssetExportSession alloc] initWithAsset:asset
                                                                      presetName:AVAssetExportPreset640x480] autorelease];
    if (!exporter) {
        [self showError:TGLoc(@"videoNote.failed")];
        return;
    }
    [exporter setOutputURL:[NSURL fileURLWithPath:destination]];
    [exporter setOutputFileType:AVFileTypeMPEG4];
    [exporter setShouldOptimizeForNetworkUse:YES];
    [exporter setVideoComposition:videoComposition];
    self.preparedPath = destination;
    self.exportSession = exporter;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            AVAssetExportSessionStatus status = [self.exportSession status];
            NSString *detail = [[[self.exportSession error] localizedDescription] copy];
            self.exportSession = nil;
            if (self.cancelling) {
                [self removeFileAtPath:destination];
            } else if (status == AVAssetExportSessionStatusCompleted) {
                [self showPreparedVideoAtPath:destination];
            } else {
                [self showError:([detail length] > 0 ? detail : TGLoc(@"videoNote.failed"))];
            }
            [detail release];
        });
    }];
}

- (void)showPreparedVideoAtPath:(NSString *)path {
    self.preparedPath = path;
    [self removeFileAtPath:self.recordingPath];
    self.recordingPath = nil;
    [self.cameraPreviewLayer removeFromSuperlayer];
    AVPlayer *player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path]];
    self.previewPlayer = player;
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    [layer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [layer setFrame:[[self.previewView layer] bounds]];
    self.playerLayer = layer;
    [[self.previewView layer] addSublayer:layer];
    [self showPreviewControls];
    [player seekToTime:kCMTimeZero];
    [player play];
}

- (void)playPressed:(id)sender {
    (void)sender;
    if (!self.previewPlayer) {
        return;
    }
    if ([self.previewPlayer rate] > 0.0) {
        [self.previewPlayer pause];
        [self.playButton setTitle:TGLoc(@"play")];
    } else {
        AVPlayerItem *item = [self.previewPlayer currentItem];
        if (item && CMTIME_IS_NUMERIC([item duration]) &&
            CMTimeCompare([self.previewPlayer currentTime], [item duration]) >= 0) {
            [self.previewPlayer seekToTime:kCMTimeZero];
        }
        [self.previewPlayer play];
        [self.playButton setTitle:TGLoc(@"pause")];
    }
}

- (void)retryPressed:(id)sender {
    (void)sender;
    [self.previewPlayer pause];
    self.previewPlayer = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    [self removeFileAtPath:self.preparedPath];
    self.preparedPath = nil;
    [self attachCameraPreviewLayer];
    if (![self.captureSession isRunning]) {
        AVCaptureSession *session = [self.captureSession retain];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [session startRunning];
            [session release];
        });
    }
    [self showReadyToRecordControls];
}

- (void)sendPressed:(id)sender {
    (void)sender;
    if ([self.preparedPath length] == 0 || self.preparing) {
        return;
    }
    NSString *path = [[self.preparedPath copy] autorelease];
    self.preparedPath = nil;
    [self.previewPlayer pause];
    [self.captureSession stopRunning];
    [[self window] orderOut:nil];
    if ([self.delegate respondsToSelector:@selector(videoNoteRecorder:didFinishVideoAtPath:)]) {
        [self.delegate videoNoteRecorder:self didFinishVideoAtPath:path];
    }
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    [self cancelAndNotify:YES];
}

- (void)cancelAndNotify:(BOOL)notify {
    self.cancelling = YES;
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
    if ([self.movieOutput isRecording]) {
        [self.movieOutput stopRecording];
    }
    [self.exportSession cancelExport];
    self.exportSession = nil;
    [self.previewPlayer pause];
    [self.captureSession stopRunning];
    [self removeFileAtPath:self.recordingPath];
    [self removeFileAtPath:self.preparedPath];
    self.recordingPath = nil;
    self.preparedPath = nil;
    [[self window] orderOut:nil];
    if (notify && [self.delegate respondsToSelector:@selector(videoNoteRecorderDidCancel:)]) {
        [self.delegate videoNoteRecorderDidCancel:self];
    }
}

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    [self cancelAndNotify:YES];
    return NO;
}

- (void)dealloc {
    [[self window] setDelegate:nil];
    [_recordingTimer invalidate];
    [_movieOutput stopRecording];
    [_exportSession cancelExport];
    [_previewPlayer pause];
    [_captureSession stopRunning];
    [_cameraPreviewLayer removeFromSuperlayer];
    [_playerLayer removeFromSuperlayer];
    [self removeFileAtPath:_recordingPath];
    [self removeFileAtPath:_preparedPath];
    [_captureSession release];
    [_movieOutput release];
    [_cameraPreviewLayer release];
    [_exportSession release];
    [_previewPlayer release];
    [_playerLayer release];
    [_previewView release];
    [_statusField release];
    [_timerField release];
    [_cameraStateImageView release];
    [_recordButton release];
    [_stopButton release];
    [_playButton release];
    [_retryButton release];
    [_cancelButton release];
    [_sendButton release];
    [_spinner release];
    [_recordingTimer release];
    [_recordingStartDate release];
    [_recordingPath release];
    [_preparedPath release];
    [super dealloc];
}

@end
