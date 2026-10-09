#import <Cocoa/Cocoa.h>
#import "TGStatusViewCells.h"

typedef struct {
    NSRect header, title, subtitle, surface, list, footer, summary, empty;
    NSRect pause, cancel, retry, reveal, clear;
} TGDownloadManagerLayout;

TGDownloadManagerLayout TGDownloadManagerLayoutForSize(NSSize size);
NSString *TGDownloadManagerByteCount(long long bytes);
NSColor *TGDownloadManagerReadableInk(NSColor *preferred, NSColor *background);

@interface TGDownloadListCell : TGRepresentedObjectCell
@end

// Opaque themed paper keeps labels readable over every window material.
@interface TGDownloadManagerSurfaceView : NSView
@end
