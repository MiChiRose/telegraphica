#import "TGWorkshopRemovalConfirmationView.h"
#import "TGWorkshopButtonCell.h"
#import "TGWorkshopSurfaceView.h"
#import "../../UI/TGIconAssets.h"

static NSTextField *TGWorkshopRemovalLabel(NSRect frame, NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    return field;
}

static NSButton *TGWorkshopRemovalButton(NSRect frame, NSString *title) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGWorkshopButtonCell *cell = [[[TGWorkshopButtonCell alloc] initTextCell:title] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setBordered:NO];
    return button;
}

static NSButton *TGWorkshopRemovalDestructiveButton(NSRect frame, NSString *title) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGWorkshopDestructiveButtonCell *cell =
        [[[TGWorkshopDestructiveButtonCell alloc] initTextCell:title] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setBordered:NO];
    return button;
}

@interface TGWorkshopRemovalConfirmationView ()
- (NSRect)panelRect;
- (void)layoutConfirmation;
- (void)beginPresentation;
- (void)dismissWithChoice:(TGWorkshopRemovalConfirmationChoice)choice;
- (void)finishDismissal;
@end

@implementation TGWorkshopRemovalConfirmationView

@synthesize delegate = _delegate;

- (id)initWithFrame:(NSRect)frame
              title:(NSString *)title
            message:(NSString *)message
      keepDataTitle:(NSString *)keepDataTitle
    removeDataTitle:(NSString *)removeDataTitle
        cancelTitle:(NSString *)cancelTitle {
    self = [super initWithFrame:frame];
    if (self) {
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        _titleField = [TGWorkshopRemovalLabel(NSZeroRect, [NSFont boldSystemFontOfSize:15.0]) retain];
        [_titleField setAlignment:NSCenterTextAlignment];
        [_titleField setTextColor:TGWorkshopCreamColor()];
        [_titleField setStringValue:title ? title : @""];
        [self addSubview:_titleField];

        _messageField = [TGWorkshopRemovalLabel(NSZeroRect, [NSFont systemFontOfSize:11.0]) retain];
        [_messageField setAlignment:NSCenterTextAlignment];
        [_messageField setTextColor:TGWorkshopMutedCreamColor()];
        [_messageField setStringValue:message ? message : @""];
        [[_messageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [[_messageField cell] setWraps:YES];
        [self addSubview:_messageField];

        _keepDataButton = [TGWorkshopRemovalDestructiveButton(NSZeroRect, keepDataTitle) retain];
        [_keepDataButton setImage:TGWorkshopUprightTemplateIcon(@"trash", NSMakeSize(15.0, 15.0),
                                                                [NSColor whiteColor], 0.88)];
        [_keepDataButton setImagePosition:NSImageLeft];
        [_keepDataButton setTarget:self];
        [_keepDataButton setAction:@selector(keepDataAction:)];
        [self addSubview:_keepDataButton];

        _removeDataButton = [TGWorkshopRemovalDestructiveButton(NSZeroRect, removeDataTitle) retain];
        [_removeDataButton setImage:TGWorkshopUprightTemplateIcon(@"trash", NSMakeSize(15.0, 15.0),
                                                                  [NSColor whiteColor], 1.0)];
        [_removeDataButton setImagePosition:NSImageLeft];
        [_removeDataButton setTarget:self];
        [_removeDataButton setAction:@selector(removeDataAction:)];
        [self addSubview:_removeDataButton];

        _cancelButton = [TGWorkshopRemovalButton(NSZeroRect, cancelTitle) retain];
        [_cancelButton setTarget:self];
        [_cancelButton setAction:@selector(cancelAction:)];
        [self addSubview:_cancelButton];

        [self layoutConfirmation];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self layoutConfirmation];
}

- (NSRect)panelRect {
    CGFloat width = MIN(610.0, MAX(440.0, NSWidth([self bounds]) - 48.0));
    CGFloat height = 238.0;
    return NSMakeRect(floor((NSWidth([self bounds]) - width) / 2.0),
                      floor((NSHeight([self bounds]) - height) / 2.0),
                      width,
                      height);
}

- (void)layoutConfirmation {
    if (!_titleField) return;
    NSRect panel = [self panelRect];
    CGFloat inset = 24.0;
    [_titleField setFrame:NSMakeRect(NSMinX(panel) + inset,
                                     NSMaxY(panel) - 43.0,
                                     NSWidth(panel) - inset * 2.0,
                                     24.0)];
    [_messageField setFrame:NSMakeRect(NSMinX(panel) + inset,
                                       NSMaxY(panel) - 99.0,
                                       NSWidth(panel) - inset * 2.0,
                                       46.0)];
    CGFloat gap = 10.0;
    CGFloat buttonWidth = floor((NSWidth(panel) - inset * 2.0 - gap) / 2.0);
    CGFloat buttonY = NSMinY(panel) + 70.0;
    [_keepDataButton setFrame:NSMakeRect(NSMinX(panel) + inset,
                                         buttonY, buttonWidth, 38.0)];
    [_removeDataButton setFrame:NSMakeRect(NSMinX(panel) + inset + buttonWidth + gap,
                                           buttonY, buttonWidth, 38.0)];
    [_cancelButton setFrame:NSMakeRect(NSMidX(panel) - 75.0,
                                       NSMinY(panel) + 20.0, 150.0, 36.0)];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithCalibratedRed:0.015 green:0.075 blue:0.055 alpha:0.34] setFill];
    NSRectFill([self bounds]);

    NSRect panelRect = [self panelRect];
    NSBezierPath *shadow = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(panelRect, -5.0, -5.0)
                                                           xRadius:15.0
                                                           yRadius:15.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.27] setFill];
    [shadow fill];

    NSBezierPath *panel = [NSBezierPath bezierPathWithRoundedRect:panelRect xRadius:11.0 yRadius:11.0];
    NSGradient *gradient = [[[NSGradient alloc]
                             initWithStartingColor:[NSColor colorWithCalibratedRed:0.055 green:0.31 blue:0.205 alpha:1.0]
                             endingColor:TGWorkshopDeepGreenColor()] autorelease];
    [gradient drawInBezierPath:panel angle:90.0];
    [TGWorkshopGoldColor() setStroke];
    [panel setLineWidth:1.0];
    [panel stroke];
}

- (void)presentInView:(NSView *)parentView {
    if (!parentView || [self superview]) return;
    [self setFrame:[parentView bounds]];
    [self setAlphaValue:0.0];
    [parentView addSubview:self positioned:NSWindowAbove relativeTo:nil];
    [[parentView window] makeFirstResponder:self];
    [self performSelector:@selector(beginPresentation) withObject:nil afterDelay:0.0];
}

- (void)beginPresentation {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.20];
    [[self animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}

- (void)dismissWithChoice:(TGWorkshopRemovalConfirmationChoice)choice {
    _pendingChoice = choice;
    [_keepDataButton setEnabled:NO];
    [_removeDataButton setEnabled:NO];
    [_cancelButton setEnabled:NO];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.22];
    [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
    [self performSelector:@selector(finishDismissal) withObject:nil afterDelay:0.24];
}

- (void)finishDismissal {
    [self retain];
    id<TGWorkshopRemovalConfirmationViewDelegate> delegate = _delegate;
    TGWorkshopRemovalConfirmationChoice choice = _pendingChoice;
    [self removeFromSuperview];
    if ([delegate respondsToSelector:@selector(workshopRemovalConfirmationView:didChoose:)]) {
        [delegate workshopRemovalConfirmationView:self didChoose:choice];
    }
    [self autorelease];
}

- (void)keepDataAction:(id)sender {
    (void)sender;
    [self dismissWithChoice:TGWorkshopRemovalConfirmationChoiceKeepData];
}

- (void)removeDataAction:(id)sender {
    (void)sender;
    [self dismissWithChoice:TGWorkshopRemovalConfirmationChoiceRemoveData];
}

- (void)cancelAction:(id)sender {
    (void)sender;
    [self dismissWithChoice:TGWorkshopRemovalConfirmationChoiceCancel];
}

- (void)keyDown:(NSEvent *)event {
    if ([event keyCode] == 53) {
        [self dismissWithChoice:TGWorkshopRemovalConfirmationChoiceCancel];
        return;
    }
    [super keyDown:event];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_titleField release];
    [_messageField release];
    [_keepDataButton release];
    [_removeDataButton release];
    [_cancelButton release];
    [super dealloc];
}

@end
