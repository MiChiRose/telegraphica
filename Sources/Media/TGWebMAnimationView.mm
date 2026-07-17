#import "TGWebMAnimationView.h"

#include <algorithm>
#include <cmath>
#include <vector>
#include "mkvparser/mkvparser.h"
#include "mkvparser/mkvreader.h"
#include "vpx/vp8dx.h"
#include "vpx/vpx_decoder.h"

static const NSUInteger TGWebMMaximumFrameCount = 180;
static const NSUInteger TGWebMMaximumSourceSide = 1024;
static const NSUInteger TGWebMTargetSide = 144;
static const CGFloat TGWebMDefaultFrameRate = 30.0;
static const CGFloat TGWebMMinimumFrameRate = 8.0;
static const CGFloat TGWebMMaximumFrameRate = 60.0;

static NSOperationQueue *TGWebMSharedDecodeQueue(void) {
    static NSOperationQueue *queue = nil;
    @synchronized([TGWebMAnimationView class]) {
        if (!queue) {
            queue = [[NSOperationQueue alloc] init];
            [queue setMaxConcurrentOperationCount:1];
        }
    }
    return queue;
}

static unsigned char TGWebMClampToByte(int value) {
    if (value < 0) {
        return 0;
    }
    if (value > 255) {
        return 255;
    }
    return (unsigned char)value;
}

static unsigned long long TGWebMChecksumForRGBA(const unsigned char *rgba, NSUInteger length) {
    unsigned long long hash = 1469598103934665603ULL;
    NSUInteger index = 0;
    for (index = 0; index < length; index++) {
        hash ^= (unsigned long long)rgba[index];
        hash *= 1099511628211ULL;
    }
    return hash;
}

static NSImage *TGWebMCreateImageFromI420(vpx_image_t *image, NSUInteger targetWidth, NSUInteger targetHeight, unsigned long long *checksum) {
    if (!image || image->fmt != VPX_IMG_FMT_I420 || image->d_w == 0 || image->d_h == 0 || targetWidth == 0 || targetHeight == 0) {
        return nil;
    }

    NSUInteger length = targetWidth * targetHeight * 4;
    NSMutableData *pixels = [NSMutableData dataWithLength:length];
    unsigned char *rgba = (unsigned char *)[pixels mutableBytes];
    NSUInteger x = 0;
    NSUInteger y = 0;

    for (y = 0; y < targetHeight; y++) {
        unsigned int sourceY = (unsigned int)((y * image->d_h) / targetHeight);
        if (sourceY >= image->d_h) {
            sourceY = image->d_h - 1;
        }
        for (x = 0; x < targetWidth; x++) {
            unsigned int sourceX = (unsigned int)((x * image->d_w) / targetWidth);
            if (sourceX >= image->d_w) {
                sourceX = image->d_w - 1;
            }
            int yValue = image->planes[VPX_PLANE_Y][sourceY * image->stride[VPX_PLANE_Y] + sourceX];
            int uValue = image->planes[VPX_PLANE_U][(sourceY / 2) * image->stride[VPX_PLANE_U] + (sourceX / 2)];
            int vValue = image->planes[VPX_PLANE_V][(sourceY / 2) * image->stride[VPX_PLANE_V] + (sourceX / 2)];
            int c = yValue - 16;
            int d = uValue - 128;
            int e = vValue - 128;
            unsigned char *pixel = rgba + ((y * targetWidth + x) * 4);
            pixel[0] = TGWebMClampToByte((298 * c + 409 * e + 128) >> 8);
            pixel[1] = TGWebMClampToByte((298 * c - 100 * d - 208 * e + 128) >> 8);
            pixel[2] = TGWebMClampToByte((298 * c + 516 * d + 128) >> 8);
            pixel[3] = 255;
        }
    }

    if (checksum) {
        *checksum = TGWebMChecksumForRGBA(rgba, length);
    }

    NSBitmapImageRep *representation = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                                pixelsWide:(NSInteger)targetWidth
                                                                                pixelsHigh:(NSInteger)targetHeight
                                                                             bitsPerSample:8
                                                                           samplesPerPixel:4
                                                                                  hasAlpha:YES
                                                                                  isPlanar:NO
                                                                            colorSpaceName:NSCalibratedRGBColorSpace
                                                                               bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                                                                bytesPerRow:(NSInteger)(targetWidth * 4)
                                                                               bitsPerPixel:32] autorelease];
    if (!representation) {
        return nil;
    }
    memcpy([representation bitmapData], rgba, length);
    NSImage *decodedImage = [[[NSImage alloc] initWithSize:NSMakeSize(targetWidth, targetHeight)] autorelease];
    [decodedImage addRepresentation:representation];
    return decodedImage;
}

static NSDictionary *TGWebMDecodeFramesAtPath(NSString *path, NSSize viewSize) {
    if ([path length] == 0) {
        return nil;
    }

    mkvparser::MkvReader reader;
    if (reader.Open([path fileSystemRepresentation]) != 0) {
        return nil;
    }

    long long position = 0;
    mkvparser::EBMLHeader header;
    if (header.Parse(&reader, position) < 0) {
        reader.Close();
        return nil;
    }

    mkvparser::Segment *segment = NULL;
    long long createResult = mkvparser::Segment::CreateInstance(&reader, position, segment);
    if (createResult < 0 || !segment) {
        reader.Close();
        return nil;
    }

    if (segment->Load() < 0) {
        delete segment;
        reader.Close();
        return nil;
    }

    const mkvparser::Tracks *tracks = segment->GetTracks();
    const mkvparser::VideoTrack *videoTrack = NULL;
    unsigned long trackIndex = 0;
    for (trackIndex = 0; tracks && trackIndex < tracks->GetTracksCount(); trackIndex++) {
        const mkvparser::Track *track = tracks->GetTrackByIndex(trackIndex);
        if (track && track->GetType() == mkvparser::Track::kVideo && track->GetCodecId() && strcmp(track->GetCodecId(), "V_VP9") == 0) {
            videoTrack = static_cast<const mkvparser::VideoTrack *>(track);
            break;
        }
    }

    if (!videoTrack || videoTrack->GetWidth() <= 0 || videoTrack->GetHeight() <= 0 ||
        videoTrack->GetWidth() > TGWebMMaximumSourceSide || videoTrack->GetHeight() > TGWebMMaximumSourceSide) {
        delete segment;
        reader.Close();
        return nil;
    }

    CGFloat frameRate = videoTrack->GetFrameRate() > 0.0 ? (CGFloat)videoTrack->GetFrameRate() : TGWebMDefaultFrameRate;
    if (frameRate < TGWebMMinimumFrameRate || frameRate > TGWebMMaximumFrameRate) {
        frameRate = TGWebMDefaultFrameRate;
    }

    CGFloat sourceWidth = (CGFloat)videoTrack->GetWidth();
    CGFloat sourceHeight = (CGFloat)videoTrack->GetHeight();
    CGFloat scale = MIN((CGFloat)TGWebMTargetSide / sourceWidth, (CGFloat)TGWebMTargetSide / sourceHeight);
    scale = MIN(scale, MIN(MAX(1.0, viewSize.width) / sourceWidth, MAX(1.0, viewSize.height) / sourceHeight));
    if (scale <= 0.0) {
        scale = 1.0;
    }
    NSUInteger targetWidth = MAX((NSUInteger)1, (NSUInteger)floor(sourceWidth * scale));
    NSUInteger targetHeight = MAX((NSUInteger)1, (NSUInteger)floor(sourceHeight * scale));

    vpx_codec_ctx_t codec;
    memset(&codec, 0, sizeof(codec));
    vpx_codec_dec_cfg_t config;
    memset(&config, 0, sizeof(config));
    config.threads = 1;
    config.w = (unsigned int)videoTrack->GetWidth();
    config.h = (unsigned int)videoTrack->GetHeight();
    if (vpx_codec_dec_init(&codec, vpx_codec_vp9_dx(), &config, 0) != VPX_CODEC_OK) {
        delete segment;
        reader.Close();
        return nil;
    }

    NSMutableArray *frames = [NSMutableArray array];
    unsigned long long lastChecksum = 0;
    const mkvparser::Cluster *cluster = segment->GetFirst();
    while (cluster && !cluster->EOS() && [frames count] < TGWebMMaximumFrameCount) {
        const mkvparser::BlockEntry *entry = NULL;
        if (cluster->GetFirst(entry) < 0) {
            break;
        }
        while (entry && !entry->EOS() && [frames count] < TGWebMMaximumFrameCount) {
            const mkvparser::Block *block = entry->GetBlock();
            if (block && block->GetTrackNumber() == videoTrack->GetNumber()) {
                int frameIndex = 0;
                for (frameIndex = 0; frameIndex < block->GetFrameCount() && [frames count] < TGWebMMaximumFrameCount; frameIndex++) {
                    const mkvparser::Block::Frame &frame = block->GetFrame(frameIndex);
                    std::vector<unsigned char> frameData((size_t)frame.len);
                    if (frame.Read(&reader, &frameData[0]) == 0 &&
                        vpx_codec_decode(&codec, &frameData[0], (unsigned int)frameData.size(), NULL, 0) == VPX_CODEC_OK) {
                        vpx_codec_iter_t iterator = NULL;
                        vpx_image_t *decoded = NULL;
                        while ((decoded = vpx_codec_get_frame(&codec, &iterator)) != NULL && [frames count] < TGWebMMaximumFrameCount) {
                            unsigned long long checksum = 0;
                            NSImage *decodedImage = TGWebMCreateImageFromI420(decoded, targetWidth, targetHeight, &checksum);
                            if (decodedImage) {
                                [frames addObject:decodedImage];
                                lastChecksum = checksum;
                            }
                        }
                    }
                }
            }
            const mkvparser::BlockEntry *nextEntry = NULL;
            if (cluster->GetNext(entry, nextEntry) < 0) {
                break;
            }
            entry = nextEntry;
        }
        cluster = segment->GetNext(cluster);
    }

    vpx_codec_destroy(&codec);
    delete segment;
    reader.Close();

    if ([frames count] == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            frames, @"frames",
            [NSNumber numberWithDouble:frameRate], @"frameRate",
            [NSNumber numberWithUnsignedLongLong:lastChecksum], @"checksum",
            nil];
}

@interface TGWebMAnimationView ()
- (void)decodeInBackground:(NSString *)path;
- (void)applyDecodedFrames:(NSDictionary *)payload;
- (void)advanceFrame:(NSTimer *)timer;
- (void)startFrameTimer;
- (void)stopFrameTimer;
@end

@implementation TGWebMAnimationView

- (instancetype)initWithFrame:(NSRect)frame webmPath:(NSString *)path {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self setWantsLayer:YES];
    [[self layer] setMasksToBounds:YES];
    [[self layer] setCornerRadius:7.0];
    _lastAppliedFrame = NSNotFound;
    _frameRate = TGWebMDefaultFrameRate;
    _decodeQueue = [TGWebMSharedDecodeQueue() retain];
    _decodePending = YES;
    NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                              selector:@selector(decodeInBackground:)
                                                                                object:[[path copy] autorelease]] autorelease];
    [_decodeQueue addOperation:operation];
    return self;
}

- (BOOL)isAnimationValid {
    return _animationValid;
}

- (void)decodeInBackground:(NSString *)path {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDictionary *payload = TGWebMDecodeFramesAtPath(path, [self bounds].size);
    [self performSelectorOnMainThread:@selector(applyDecodedFrames:)
                           withObject:payload
                        waitUntilDone:NO];
    [pool drain];
}

- (void)applyDecodedFrames:(NSDictionary *)payload {
    _decodePending = NO;
    NSArray *decodedFrames = [payload objectForKey:@"frames"];
    if ([decodedFrames count] == 0) {
        _animationValid = NO;
        [self setNeedsDisplay:YES];
        return;
    }
    [_frames release];
    _frames = [decodedFrames retain];
    _frameRate = [[payload objectForKey:@"frameRate"] doubleValue];
    _currentFrameChecksum = [[payload objectForKey:@"checksum"] unsignedLongLongValue];
    _lastAppliedFrame = 0;
    _renderedFrameCount = [_frames count];
    _animationValid = YES;
    [self setNeedsDisplay:YES];
    if (_playbackActive) {
        [self startFrameTimer];
    }
}

- (void)setPlaybackActive:(BOOL)active {
    _playbackActive = active;
    if (active) {
        [self startFrameTimer];
    } else {
        [self stopFrameTimer];
    }
}

- (void)startFrameTimer {
    if (!_animationValid || [_frames count] <= 1 || _frameTimer) {
        return;
    }
    _playbackStartDate = [[NSDate date] retain];
    _frameTimer = [[NSTimer scheduledTimerWithTimeInterval:MAX(1.0 / _frameRate, 1.0 / TGWebMMaximumFrameRate)
                                                    target:self
                                                  selector:@selector(advanceFrame:)
                                                  userInfo:nil
                                                   repeats:YES] retain];
}

- (void)stopFrameTimer {
    [_frameTimer invalidate];
    [_frameTimer release];
    _frameTimer = nil;
    [_playbackStartDate release];
    _playbackStartDate = nil;
}

- (void)advanceFrame:(NSTimer *)timer {
    (void)timer;
    if (!_animationValid || [_frames count] == 0 || !_playbackStartDate) {
        return;
    }
    NSTimeInterval elapsed = -[_playbackStartDate timeIntervalSinceNow];
    NSUInteger frameIndex = ((NSUInteger)floor(elapsed * _frameRate)) % [_frames count];
    if (frameIndex != _lastAppliedFrame) {
        _lastAppliedFrame = frameIndex;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:7.0 yRadius:7.0];
    [clipPath addClip];
    [[NSColor clearColor] setFill];
    NSRectFill([self bounds]);
    if (_animationValid && [_frames count] > 0) {
        NSUInteger frameIndex = _lastAppliedFrame == NSNotFound ? 0 : MIN(_lastAppliedFrame, [_frames count] - 1);
        NSImage *frame = [_frames objectAtIndex:frameIndex];
        NSSize imageSize = [frame size];
        if (imageSize.width > 0.0 && imageSize.height > 0.0) {
            NSRect bounds = [self bounds];
            [frame drawInRect:bounds
                     fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
                    operation:NSCompositeSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];
        }
    }
}

- (BOOL)isOpaque {
    return NO;
}

- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (NSUInteger)renderedFrameCount {
    return _renderedFrameCount;
}

- (NSUInteger)lastAppliedFrame {
    return _lastAppliedFrame;
}

- (unsigned long long)currentFrameChecksum {
    return _currentFrameChecksum;
}

- (void)dealloc {
    [self stopFrameTimer];
    [_frames release];
    [_decodeQueue release];
    [super dealloc];
}

@end
