#import "TGSectionTitleField.h"
#import "TGIconAssets.h"

@implementation TGSectionTitleField

@synthesize iconName = _iconName;

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setEditable:NO];
        [self setSelectable:NO];
        [self setBordered:NO];
        [self setDrawsBackground:NO];
        [self setFont:[NSFont systemFontOfSize:13.0]];
    }
    return self;
}

- (void)dealloc {
    [_iconName release];
    [super dealloc];
}

- (void)setIconName:(NSString *)iconName {
    if (_iconName != iconName) {
        [_iconName release];
        _iconName = [iconName copy];
        [self setNeedsDisplay:YES];
    }
}

- (void)setStringValue:(NSString *)aString {
    [super setStringValue:(aString ? aString : @"")];
    [self setNeedsDisplay:YES];
}

- (void)setTextColor:(NSColor *)textColor {
    [super setTextColor:textColor];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSString *title = [self stringValue];
    if ([title length] == 0) {
        return;
    }

    NSRect bounds = [self bounds];
    NSColor *textColor = [self textColor] ? [self textColor] : [NSColor darkGrayColor];
    CGFloat textX = 0.0;
    if ([self.iconName length] > 0) {
        CGFloat iconSide = 14.0;
        NSRect iconRect = NSMakeRect(NSMinX(bounds),
                                     floor(NSMidY(bounds) - (iconSide / 2.0)),
                                     iconSide,
                                     iconSide);
        TGDrawTemplateIconAsset(self.iconName, iconRect, textColor, 0.88, [self isFlipped]);
        textX = iconSide + 7.0;
    }

    NSFont *font = [self font] ? [self font] : [NSFont systemFontOfSize:13.0];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                textColor, NSForegroundColorAttributeName,
                                nil];
    NSSize titleSize = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMinX(bounds) + textX,
                                  floor(NSMidY(bounds) - (titleSize.height / 2.0)),
                                  MAX(0.0, NSWidth(bounds) - textX),
                                  titleSize.height + 1.0);
    [title drawInRect:titleRect withAttributes:attributes];
}

@end
