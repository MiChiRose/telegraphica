#import "TGSavedMessagesCell.h"
#import "TGTheme.h"
#import "../Media/TGMediaImageLoader.h"

@implementation TGSavedMessagesCell

static NSMutableSet *TGSavedMessagesPendingImagePaths(void) {
    static NSMutableSet *paths = nil;
    if (!paths) {
        paths = [[NSMutableSet alloc] init];
    }
    return paths;
}

- (id)copyWithZone:(NSZone *)zone {
    return [super copyWithZone:zone];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    id value = [self objectValue];
    if (![value isKindOfClass:[NSDictionary class]]) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    NSDictionary *row = (NSDictionary *)value;
    NSString *title = [[row objectForKey:@"title"] isKindOfClass:[NSString class]]
        ? [row objectForKey:@"title"] : @"";
    NSString *detail = [[row objectForKey:@"detail"] isKindOfClass:[NSString class]]
        ? [row objectForKey:@"detail"] : @"";
    NSString *imagePath = [[row objectForKey:@"image_path"] isKindOfClass:[NSString class]]
        ? [row objectForKey:@"image_path"] : nil;
    BOOL highlighted = [self isHighlighted];
    NSColor *titleColor = highlighted ? [NSColor whiteColor] : TGClassicCardInkColor();
    NSColor *detailColor = highlighted
        ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.82]
        : TGClassicCardMutedInkColor();

    NSMutableParagraphStyle *singleLine = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [singleLine setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     titleColor, NSForegroundColorAttributeName,
                                     singleLine, NSParagraphStyleAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                      detailColor, NSForegroundColorAttributeName,
                                      singleLine, NSParagraphStyleAttributeName,
                                      nil];
    CGFloat textX = NSMinX(cellFrame) + 7.0;
    CGFloat textWidth = NSWidth(cellFrame) - 14.0;
    if ([imagePath length] > 0) {
        NSRect imageRect = NSMakeRect(NSMinX(cellFrame) + 6.0, NSMinY(cellFrame) + 6.0,
                                      58.0, MAX(24.0, NSHeight(cellFrame) - 12.0));
        textX = NSMaxX(imageRect) + 10.0;
        textWidth = NSMaxX(cellFrame) - textX - 7.0;
        NSImage *image = TGMediaCachedThumbnailFromFile(imagePath, 120);
        if (!image) {
            NSString *pendingKey = [NSString stringWithFormat:@"120:%@", [imagePath stringByStandardizingPath]];
            BOOL shouldStart = NO;
            @synchronized([TGSavedMessagesCell class]) {
                if (![TGSavedMessagesPendingImagePaths() containsObject:pendingKey]) {
                    [TGSavedMessagesPendingImagePaths() addObject:pendingKey];
                    shouldStart = YES;
                }
            }
            if (shouldStart) {
                TGLoadImageThumbnailFromFileAsync(imagePath, 120, ^(NSImage *loadedImage) {
                    (void)loadedImage;
                    @synchronized([TGSavedMessagesCell class]) {
                        [TGSavedMessagesPendingImagePaths() removeObject:pendingKey];
                    }
                    if ([controlView window]) {
                        [controlView setNeedsDisplay:YES];
                    }
                });
            }
        }
        if (image) {
            [image drawInRect:imageRect
                    fromRect:NSZeroRect
                   operation:NSCompositeSourceOver
                    fraction:1.0
              respectFlipped:YES
                       hints:nil];
        } else {
            [[TGClassicPanelStrokeColor() colorWithAlphaComponent:0.12] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:imageRect xRadius:5.0 yRadius:5.0] fill];
        }
    }
    NSRect titleRect = NSMakeRect(textX, NSMinY(cellFrame) + 7.0, textWidth, 18.0);
    titleRect.size.height = 17.0;
    NSRect detailRect = NSMakeRect(NSMinX(titleRect),
                                   NSMinY(cellFrame) + 27.0,
                                   NSWidth(titleRect),
                                   MAX(15.0, NSHeight(cellFrame) - 33.0));
    [title drawInRect:titleRect withAttributes:titleAttributes];
    [detail drawInRect:detailRect withAttributes:detailAttributes];
}

@end
