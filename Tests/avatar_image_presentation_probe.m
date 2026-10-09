#import <Cocoa/Cocoa.h>
#import "TGAvatarImagePresentation.h"
#import "TGMediaImageLoader.h"
#include <stdio.h>

BOOL TGDataHasWebPHeader(NSData *data) { (void)data; return NO; }
NSImage *TGWebPImageFromData(NSData *data) { (void)data; return nil; }
NSImage *TGWebPImageFromFile(NSString *path) { (void)path; return nil; }

@interface TGAvatarProbeView : NSView { NSUInteger _invalidations; }
@property (nonatomic, readonly) NSUInteger invalidations;
@end
@implementation TGAvatarProbeView
- (NSUInteger)invalidations { return _invalidations; }
- (void)setNeedsDisplay:(BOOL)flag { if (flag) { _invalidations++; } [super setNeedsDisplay:flag]; }
@end

static void TGAssert(BOOL valid, const char *message) {
    if (!valid) { fprintf(stderr, "Avatar presentation failure: %s\n", message); exit(1); }
}

static void TGWait(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([end timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"telegraphica-avatar-%u", arc4random()]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *firstPath = [directory stringByAppendingPathComponent:@"first.png"];
    NSString *secondPath = [directory stringByAppendingPathComponent:@"second.png"];
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
    memset([bitmap bitmapData], 255, [bitmap bytesPerRow] * [bitmap pixelsHigh]);
    NSData *png = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    TGAssert([png writeToFile:firstPath atomically:YES] && [png writeToFile:secondPath atomically:YES], "write fixtures");
    TGMediaImageLoaderClearCache();
    TGAvatarProbeView *view = [[[TGAvatarProbeView alloc] initWithFrame:NSMakeRect(0, 0, 44, 44)] autorelease];
    TGAvatarImagePresentation *presentation = [[TGAvatarImagePresentation alloc] initWithView:view];
    [presentation setPath:firstPath];
    TGAssert([presentation imageForDrawing] == nil, "uncached avatar must decode asynchronously");
    TGWait(0.5);
    NSImage *decoded = [presentation imageForDrawing];
    TGAssert(decoded != nil && [view invalidations] > 0, "completion must invalidate standalone sidebar avatar");
    TGMediaImageLoaderClearCache();
    TGAssert([presentation imageForDrawing] == decoded, "cache eviction must not replace a visible avatar with initials");
    [presentation setPath:firstPath];
    TGAssert([presentation imageForDrawing] == decoded, "unchanged same-path summary must preserve the decoded visible image");
    NSBitmapImageRep *replacement = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:24 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
    memset([replacement bitmapData], 160, [replacement bytesPerRow] * [replacement pixelsHigh]);
    NSData *replacementPNG = [replacement representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    TGAssert([replacementPNG writeToFile:firstPath atomically:YES], "atomically replace avatar bytes at the same path");
    [presentation setPath:firstPath];
    TGWait(0.5);
    NSImage *replaced = [presentation imageForDrawing];
    TGAssert(replaced != nil && [replaced size].width == 32.0 && [replaced size].height == 24.0,
             "same-path completed file must display the new avatar dimensions");
    TGMediaImageLoaderClearCache();
    [presentation setPath:firstPath];
    TGAssert([presentation imageForDrawing] == replaced, "unchanged replacement must survive cache eviction too");
    [presentation setPath:nil];
    TGAssert([presentation imageForDrawing] == nil, "explicit photo removal must discard old avatar");
    [presentation setPath:firstPath];
    [presentation setPath:secondPath];
    TGWait(0.5);
    TGAssert([presentation imageForDrawing] == TGMediaCachedThumbnailFromFile(secondPath, 128), "superseded completion must not restore the previous avatar");
    NSString *latePath = [directory stringByAppendingPathComponent:@"late.png"];
    [presentation setPath:latePath];
    TGWait(0.2);
    TGAssert([presentation imageForDrawing] == nil, "missing download path must use normal fallback");
    TGAssert([png writeToFile:latePath atomically:YES], "complete late file fixture");
    [presentation setPath:latePath];
    TGWait(0.3);
    TGAssert([presentation imageForDrawing] != nil, "fresh same-path file completion must retry decoding immediately");
    TGMediaImageLoaderClearCache();
    [presentation setPath:nil];
    [presentation setPath:firstPath];
    NSUInteger before = [view invalidations];
    [presentation release];
    TGWait(0.5);
    TGAssert([view invalidations] == before, "deallocation must cancel callback without retaining view/presentation");
    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    puts("Avatar presentation probe passed.");
    [pool drain];
    return 0;
}
