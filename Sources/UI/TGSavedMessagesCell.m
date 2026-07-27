#import "TGSavedMessagesCell.h"
#import "TGTheme.h"

@implementation TGSavedMessagesCell

static NSCache *TGSavedMessagesImageCache(void) {
    static NSCache *cache = nil;
    if (!cache) {
        cache = [[NSCache alloc] init];
        [cache setCountLimit:80];
    }
    return cache;
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
        NSImage *image = [TGSavedMessagesImageCache() objectForKey:imagePath];
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
            if (image) {
                [TGSavedMessagesImageCache() setObject:image forKey:imagePath];
            }
        }
        if (image) {
            NSRect imageRect = NSMakeRect(NSMinX(cellFrame) + 6.0, NSMinY(cellFrame) + 6.0,
                                          58.0, MAX(24.0, NSHeight(cellFrame) - 12.0));
            [image drawInRect:imageRect
                    fromRect:NSZeroRect
                   operation:NSCompositeSourceOver
                    fraction:1.0
              respectFlipped:YES
                       hints:nil];
            textX = NSMaxX(imageRect) + 10.0;
            textWidth = NSMaxX(cellFrame) - textX - 7.0;
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
