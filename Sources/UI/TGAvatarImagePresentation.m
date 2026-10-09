#import "TGAvatarImagePresentation.h"
#import "../Media/TGMediaImageLoader.h"

@interface TGAvatarImagePresentation ()
@property (nonatomic, copy) NSArray *sourceFingerprint;
@end

static NSArray *TGAvatarFileFingerprint(NSString *path) {
    if ([path length] == 0) { return nil; }
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if (!attributes) { return nil; }
    return [NSArray arrayWithObjects:
        [attributes objectForKey:NSFileSystemFileNumber] ?: @0,
        [attributes objectForKey:NSFileSize] ?: @0,
        [attributes objectForKey:NSFileModificationDate] ?: [NSDate distantPast], nil];
}

@implementation TGAvatarImagePresentation

@synthesize sourceFingerprint = _sourceFingerprint;

- (id)initWithView:(NSView *)view {
    self = [super init];
    if (self) { _view = view; }
    return self;
}

- (void)setPath:(NSString *)path {
    NSArray *fingerprint = TGAvatarFileFingerprint(path);
    BOOL samePath = (_path == path || [_path isEqualToString:path]);
    BOOL sameFile = (_sourceFingerprint == fingerprint || [_sourceFingerprint isEqualToArray:fingerprint]);
    if (samePath && sameFile) {
        // A fresh completed-file/profile summary may make the same path
        // readable after an earlier decode failed while it was downloading.
        if (!_image) { _retryAfter = 0.0; [self imageForDrawing]; }
        return;
    }
    [_loadToken cancel];
    [_loadToken release];
    _loadToken = nil;
    if (!samePath) {
        [_path release];
        _path = [path copy];
    }
    self.sourceFingerprint = fingerprint;
    [_image release];
    _image = nil;
    _retryAfter = 0.0;
    [self imageForDrawing];
}

- (NSImage *)imageForDrawing {
    if (_image || [_path length] == 0 || _loadToken ||
        [NSDate timeIntervalSinceReferenceDate] < _retryAfter) { return _image; }
    NSImage *cached = TGMediaCachedThumbnailFromFile(_path, 128);
    if (cached) {
        _image = [cached retain];
        return _image;
    }
    // Under MRC __block does not retain self. All callbacks and view lifecycle
    // run on the main thread; dealloc cancels and clears the token's block.
    __block TGAvatarImagePresentation *presentation = self;
    NSArray *requestFingerprint = TGAvatarFileFingerprint(_path);
    _loadToken = [TGLoadImageThumbnailFromFileAsync(_path, 128, ^(NSImage *image) {
        NSArray *currentFingerprint = TGAvatarFileFingerprint(presentation->_path);
        BOOL sameFile = (requestFingerprint == currentFingerprint || [requestFingerprint isEqualToArray:currentFingerprint]);
        [presentation->_image release];
        presentation->_image = sameFile ? [image retain] : nil;
        presentation.sourceFingerprint = currentFingerprint;
        [presentation->_loadToken release];
        presentation->_loadToken = nil;
        presentation->_retryAfter = sameFile && !image ? [NSDate timeIntervalSinceReferenceDate] + 5.0 : 0.0;
        if (!sameFile) { [presentation imageForDrawing]; }
        [presentation->_view setNeedsDisplay:YES];
    }) retain];
    return _image;
}

- (void)dealloc {
    [_loadToken cancel];
    [_loadToken release];
    [_path release];
    [_image release];
    [_sourceFingerprint release];
    [super dealloc];
}

@end
