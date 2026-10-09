#import <Cocoa/Cocoa.h>

@class TGMessageItem;

NSColor *TGMessageMetadataSurfaceColor(TGMessageItem *item, BOOL flipped);
NSColor *TGMessageMetadataInkColor(TGMessageItem *item, BOOL flipped);
NSColor *TGMessageDeliveryStatusInkColor(TGMessageItem *item, BOOL active, BOOL flipped);
