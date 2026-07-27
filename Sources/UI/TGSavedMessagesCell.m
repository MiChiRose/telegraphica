#import "TGSavedMessagesCell.h"
#import "TGTheme.h"

@implementation TGSavedMessagesCell

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
    NSRect titleRect = NSInsetRect(cellFrame, 7.0, 4.0);
    titleRect.size.height = 17.0;
    NSRect detailRect = NSMakeRect(NSMinX(titleRect),
                                   NSMinY(cellFrame) + 23.0,
                                   NSWidth(titleRect),
                                   MAX(15.0, NSHeight(cellFrame) - 27.0));
    [title drawInRect:titleRect withAttributes:titleAttributes];
    [detail drawInRect:detailRect withAttributes:detailAttributes];
}

@end
