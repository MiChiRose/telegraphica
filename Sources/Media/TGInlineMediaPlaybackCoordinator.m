#import "TGInlineMediaPlaybackCoordinator.h"
#import <AVFoundation/AVFoundation.h>

NSString * const TGInlineMediaIdentifierKey = @"identifier";
NSString * const TGInlineMediaPathKey = @"path";
NSString * const TGInlineMediaFrameKey = @"frame";

@interface TGInlineMediaPlaybackView : NSView
@property (nonatomic, retain) AVPlayer *player;
@property (nonatomic, retain) AVPlayerLayer *playerLayer;
@property (nonatomic, retain) NSImageView *imageView;
@property (nonatomic, copy) NSString *mediaPath;
- (instancetype)initWithFrame:(NSRect)frame mediaPath:(NSString *)mediaPath;
- (void)setPlaybackActive:(BOOL)active;
@end

@implementation TGInlineMediaPlaybackView

@synthesize player = _player;
@synthesize playerLayer = _playerLayer;
@synthesize imageView = _imageView;
@synthesize mediaPath = _mediaPath;

static BOOL TGInlineMediaPathContainsGIF(NSString *path) {
    if ([[[path pathExtension] lowercaseString] isEqualToString:@"gif"]) {
        return YES;
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *prefix = [handle readDataOfLength:6];
    [handle closeFile];
    if ([prefix length] != 6) {
        return NO;
    }
    NSString *signature = [[[NSString alloc] initWithData:prefix encoding:NSASCIIStringEncoding] autorelease];
    return [signature isEqualToString:@"GIF87a"] || [signature isEqualToString:@"GIF89a"];
}

- (instancetype)initWithFrame:(NSRect)frame mediaPath:(NSString *)mediaPath {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.mediaPath = mediaPath;
    [self setAutoresizingMask:NSViewNotSizable];
    [self setWantsLayer:YES];
    [[self layer] setMasksToBounds:YES];
    [[self layer] setCornerRadius:7.0];

    if (TGInlineMediaPathContainsGIF(mediaPath)) {
        NSImage *image = [[[NSImage alloc] initWithContentsOfFile:mediaPath] autorelease];
        if (image) {
            NSImageView *imageView = [[[NSImageView alloc] initWithFrame:[self bounds]] autorelease];
            [imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
            [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
            [imageView setImage:image];
            [imageView setAnimates:YES];
            [self addSubview:imageView];
            self.imageView = imageView;
        }
    } else {
        NSURL *url = [NSURL fileURLWithPath:mediaPath];
        AVPlayer *player = [[[AVPlayer alloc] initWithURL:url] autorelease];
        if (player) {
            [player setActionAtItemEnd:AVPlayerActionAtItemEndNone];
            [player setVolume:0.0];
            AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
            [playerLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            [playerLayer setFrame:[self bounds]];
            [[self layer] addSublayer:playerLayer];
            self.player = player;
            self.playerLayer = playerLayer;
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playerItemDidReachEnd:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:[player currentItem]];
        }
    }
    return self;
}

- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [self.playerLayer setFrame:[self bounds]];
    [self.imageView setFrame:[self bounds]];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if ([notification object] != [self.player currentItem]) {
        return;
    }
    [self.player seekToTime:kCMTimeZero];
    [self.player play];
}

- (void)setPlaybackActive:(BOOL)active {
    if (active) {
        [self.imageView setAnimates:YES];
        [self.player play];
    } else {
        [self.imageView setAnimates:NO];
        [self.player pause];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player pause];
    [_player release];
    [_playerLayer removeFromSuperlayer];
    [_playerLayer release];
    [_imageView release];
    [_mediaPath release];
    [super dealloc];
}

@end

@interface TGInlineMediaPlaybackCoordinator ()
@property (nonatomic, assign) NSView *hostView;
@property (nonatomic, retain) NSMutableDictionary *viewsByIdentifier;
@property (nonatomic, assign) NSUInteger maximumActiveItems;
@property (nonatomic, assign) BOOL applicationActive;
@end

@implementation TGInlineMediaPlaybackCoordinator

@synthesize hostView = _hostView;
@synthesize viewsByIdentifier = _viewsByIdentifier;
@synthesize maximumActiveItems = _maximumActiveItems;
@synthesize applicationActive = _applicationActive;

- (instancetype)initWithHostView:(NSView *)hostView maximumActiveItems:(NSUInteger)maximumActiveItems {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.hostView = hostView;
    self.maximumActiveItems = maximumActiveItems > 0 ? maximumActiveItems : 1;
    self.viewsByIdentifier = [NSMutableDictionary dictionary];
    self.applicationActive = [NSApp isActive];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidResignActive:)
                                                 name:NSApplicationDidResignActiveNotification
                                               object:NSApp];
    return self;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    self.applicationActive = YES;
    for (TGInlineMediaPlaybackView *view in [self.viewsByIdentifier allValues]) {
        [view setPlaybackActive:YES];
    }
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    (void)notification;
    self.applicationActive = NO;
    for (TGInlineMediaPlaybackView *view in [self.viewsByIdentifier allValues]) {
        [view setPlaybackActive:NO];
    }
}

- (void)updateWithDescriptors:(NSArray *)descriptors {
    if (!self.hostView) {
        [self removeAllPlayback];
        return;
    }

    NSMutableSet *retainedIdentifiers = [NSMutableSet set];
    NSUInteger accepted = 0;
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count] && accepted < self.maximumActiveItems; index++) {
        id candidate = [descriptors objectAtIndex:index];
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *descriptor = (NSDictionary *)candidate;
        NSString *identifier = [descriptor objectForKey:TGInlineMediaIdentifierKey];
        NSString *path = [descriptor objectForKey:TGInlineMediaPathKey];
        NSValue *frameValue = [descriptor objectForKey:TGInlineMediaFrameKey];
        if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0 ||
            ![path isKindOfClass:[NSString class]] || [path length] == 0 ||
            ![frameValue isKindOfClass:[NSValue class]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            continue;
        }

        NSRect frame = [frameValue rectValue];
        if (NSIsEmptyRect(frame)) {
            continue;
        }

        TGInlineMediaPlaybackView *view = [self.viewsByIdentifier objectForKey:identifier];
        if (view && ![[view mediaPath] isEqualToString:path]) {
            [view removeFromSuperview];
            [self.viewsByIdentifier removeObjectForKey:identifier];
            view = nil;
        }
        if (!view) {
            view = [[[TGInlineMediaPlaybackView alloc] initWithFrame:frame mediaPath:path] autorelease];
            if (![view player] && ![view imageView]) {
                continue;
            }
            [self.hostView addSubview:view];
            [self.viewsByIdentifier setObject:view forKey:identifier];
        }
        [view setFrame:frame];
        [view setPlaybackActive:self.applicationActive];
        [retainedIdentifiers addObject:identifier];
        accepted++;
    }

    NSArray *existingIdentifiers = [[self.viewsByIdentifier allKeys] copy];
    for (index = 0; index < [existingIdentifiers count]; index++) {
        NSString *identifier = [existingIdentifiers objectAtIndex:index];
        if ([retainedIdentifiers containsObject:identifier]) {
            continue;
        }
        TGInlineMediaPlaybackView *view = [self.viewsByIdentifier objectForKey:identifier];
        [view setPlaybackActive:NO];
        [view removeFromSuperview];
        [self.viewsByIdentifier removeObjectForKey:identifier];
    }
    [existingIdentifiers release];
}

- (void)removeAllPlayback {
    NSArray *views = [[self.viewsByIdentifier allValues] copy];
    for (TGInlineMediaPlaybackView *view in views) {
        [view setPlaybackActive:NO];
        [view removeFromSuperview];
    }
    [views release];
    [self.viewsByIdentifier removeAllObjects];
}

- (void)invalidate {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeAllPlayback];
    self.hostView = nil;
}

- (void)dealloc {
    [self invalidate];
    [_viewsByIdentifier release];
    [super dealloc];
}

@end
