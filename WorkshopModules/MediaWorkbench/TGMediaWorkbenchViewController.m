#import "TGMediaWorkbenchViewController.h"
#import "TGMediaWorkbenchProcessor.h"
#import "../Common/TGGameUI.h"

@class TGMediaWorkbenchViewController;
@interface TGMediaWorkbenchRootView : TGWorkshopGameSurfaceView {
    TGMediaWorkbenchViewController *_layoutOwner;
}
@property(nonatomic, assign) TGMediaWorkbenchViewController *layoutOwner;
@end

@interface TGMediaWorkbenchPanelView : NSView
@end
@implementation TGMediaWorkbenchPanelView
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 0.5, 0.5)
                                                        xRadius:9.0 yRadius:9.0];
    [[NSColor colorWithCalibratedRed:0.05 green:0.24 blue:0.15 alpha:0.92] setFill];
    [path fill];
    [TGWorkshopGoldColor() setStroke];
    [path stroke];
}
@end

static NSTextField *TGMediaWorkbenchLabel(CGFloat size, BOOL bold, NSColor *color) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [field setEditable:NO];
    [field setSelectable:YES];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:(bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size])];
    [field setTextColor:color];
    [[field cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [[field cell] setWraps:YES];
    return field;
}

static NSString *TGMediaWorkbenchSizeString(unsigned long long bytes) {
    if (bytes >= 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL) return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
    return [NSString stringWithFormat:@"%llu B", bytes];
}

@interface TGMediaWorkbenchViewController ()
- (void)layoutWorkbench;
- (void)chooseFile:(id)sender;
- (void)saveFile:(id)sender;
- (void)qualityChanged:(id)sender;
- (NSString *)selectedFormat;
@end

@implementation TGMediaWorkbenchRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutWorkbench];
}
@end

@implementation TGMediaWorkbenchViewController

- (id)initWithHostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _hostContext = [hostContext retain];
    return self;
}

- (void)loadView {
    TGMediaWorkbenchRootView *root = [[[TGMediaWorkbenchRootView alloc] initWithFrame:NSMakeRect(0, 0, 760, 540)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGMediaWorkbenchLabel(22.0, YES, TGWorkshopCreamColor()) retain];
    [_titleField setAlignment:NSCenterTextAlignment];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"mediaWorkbench.title"
                                                           fallback:@"Media Center"]];
    [root addSubview:_titleField];

    _hintField = [TGMediaWorkbenchLabel(12.0, NO, TGWorkshopMutedCreamColor()) retain];
    [_hintField setAlignment:NSCenterTextAlignment];
    [_hintField setStringValue:[_hostContext localizedStringForKey:@"mediaWorkbench.hint"
                                                          fallback:@"Compress, resize and convert an image locally. Files are never uploaded."]];
    [root addSubview:_hintField];

    TGMediaWorkbenchPanelView *panel = [[[TGMediaWorkbenchPanelView alloc] initWithFrame:NSZeroRect] autorelease];
    _panelView = [panel retain];
    [root addSubview:panel];

    _previewView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    [_previewView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [_previewView setImageFrameStyle:NSImageFramePhoto];
    [panel addSubview:_previewView];

    _fileField = [TGMediaWorkbenchLabel(12.0, YES, TGWorkshopCreamColor()) retain];
    [_fileField setStringValue:[_hostContext localizedStringForKey:@"mediaWorkbench.noFile"
                                                          fallback:@"No image selected"]];
    [panel addSubview:_fileField];

    _chooseButton = [TGGameThemedButton(NSZeroRect,
                                         [_hostContext localizedStringForKey:@"mediaWorkbench.choose"
                                                                     fallback:@"Choose image"],
                                         @"image", _hostContext) retain];
    [_chooseButton setTarget:self];
    [_chooseButton setAction:@selector(chooseFile:)];
    [panel addSubview:_chooseButton];

    _formatPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_formatPopup addItemsWithTitles:[NSArray arrayWithObjects:@"JPEG", @"PNG", @"TIFF", nil]];
    [panel addSubview:_formatPopup];

    _sizePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_sizePopup addItemWithTitle:[_hostContext localizedStringForKey:@"mediaWorkbench.originalSize"
                                                            fallback:@"Original size"]];
    [[_sizePopup lastItem] setRepresentedObject:[NSNumber numberWithUnsignedInteger:0]];
    NSArray *sizes = [NSArray arrayWithObjects:@2048, @1280, @800, @480, nil];
    NSNumber *size = nil;
    for (size in sizes) {
        [_sizePopup addItemWithTitle:[NSString stringWithFormat:@"Max %@ px", size]];
        [[_sizePopup lastItem] setRepresentedObject:size];
    }
    [panel addSubview:_sizePopup];

    _qualitySlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    [_qualitySlider setMinValue:20.0];
    [_qualitySlider setMaxValue:100.0];
    [_qualitySlider setDoubleValue:85.0];
    [_qualitySlider setTarget:self];
    [_qualitySlider setAction:@selector(qualityChanged:)];
    [panel addSubview:_qualitySlider];

    _qualityField = [TGMediaWorkbenchLabel(11.0, NO, TGWorkshopMutedCreamColor()) retain];
    [panel addSubview:_qualityField];
    [self qualityChanged:nil];

    _saveButton = [TGGameThemedButton(NSZeroRect,
                                       [_hostContext localizedStringForKey:@"mediaWorkbench.save"
                                                                   fallback:@"Convert and save"],
                                       @"archive", _hostContext) retain];
    [_saveButton setTarget:self];
    [_saveButton setAction:@selector(saveFile:)];
    [_saveButton setEnabled:NO];
    [panel addSubview:_saveButton];

    _statusField = [TGMediaWorkbenchLabel(11.0, NO, TGWorkshopMutedCreamColor()) retain];
    [_statusField setAlignment:NSCenterTextAlignment];
    [panel addSubview:_statusField];

    _spinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    [_spinner setStyle:NSProgressIndicatorSpinningStyle];
    [_spinner setDisplayedWhenStopped:NO];
    [panel addSubview:_spinner];

    [self layoutWorkbench];
}

- (void)layoutWorkbench {
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(680.0, width - 36.0);
    CGFloat x = floor((width - contentWidth) / 2.0);
    [_titleField setFrame:NSMakeRect(x, height - 48.0, contentWidth, 28.0)];
    [_hintField setFrame:NSMakeRect(x, height - 76.0, contentWidth, 32.0)];
    NSView *panel = _panelView;
    [panel setFrame:NSMakeRect(x, 20.0, contentWidth, height - 110.0)];
    CGFloat panelWidth = NSWidth([panel bounds]);
    CGFloat panelHeight = NSHeight([panel bounds]);
    [_previewView setFrame:NSMakeRect(20.0, panelHeight - 230.0, 250.0, 190.0)];
    [_fileField setFrame:NSMakeRect(292.0, panelHeight - 92.0, panelWidth - 312.0, 45.0)];
    [_chooseButton setFrame:NSMakeRect(292.0, panelHeight - 140.0, 190.0, 34.0)];
    [_formatPopup setFrame:NSMakeRect(292.0, panelHeight - 196.0, 145.0, 26.0)];
    [_sizePopup setFrame:NSMakeRect(448.0, panelHeight - 196.0, panelWidth - 468.0, 26.0)];
    [_qualityField setFrame:NSMakeRect(22.0, 118.0, 150.0, 20.0)];
    [_qualitySlider setFrame:NSMakeRect(170.0, 112.0, panelWidth - 192.0, 24.0)];
    [_saveButton setFrame:NSMakeRect(floor((panelWidth - 210.0) / 2.0), 58.0, 210.0, 36.0)];
    [_statusField setFrame:NSMakeRect(22.0, 18.0, panelWidth - 44.0, 30.0)];
    [_spinner setFrame:NSMakeRect(NSMaxX([_saveButton frame]) + 10.0, 67.0, 18.0, 18.0)];
}

- (void)chooseFile:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"tif", @"tiff", @"bmp", @"gif", nil]];
    if ([panel runModal] != NSOKButton) return;
    NSString *path = [[panel URL] path];
    NSError *error = nil;
    NSDictionary *information = [TGMediaWorkbenchProcessor imageInformationAtPath:path error:&error];
    if (!information) {
        [_statusField setStringValue:[error localizedDescription]];
        return;
    }
    [_sourcePath release];
    _sourcePath = [path copy];
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    [_previewView setImage:image];
    [_fileField setStringValue:[NSString stringWithFormat:@"%@\n%@ x %@  •  %@",
        [information objectForKey:@"file_name"],
        [information objectForKey:@"width"],
        [information objectForKey:@"height"],
        TGMediaWorkbenchSizeString([[information objectForKey:@"file_size"] unsignedLongLongValue])]];
    [_statusField setStringValue:@""];
    [_saveButton setEnabled:YES];
}

- (NSString *)selectedFormat {
    switch ([_formatPopup indexOfSelectedItem]) {
        case 1: return TGMediaWorkbenchOutputPNG;
        case 2: return TGMediaWorkbenchOutputTIFF;
        default: return TGMediaWorkbenchOutputJPEG;
    }
}

- (void)saveFile:(id)sender {
    (void)sender;
    if (_processing || [_sourcePath length] == 0) return;
    NSString *format = [self selectedFormat];
    NSString *extension = [format isEqualToString:TGMediaWorkbenchOutputJPEG] ? @"jpg" : format;
    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString *baseName = [[[_sourcePath lastPathComponent] stringByDeletingPathExtension]
                          stringByAppendingString:@"-processed"];
    [panel setNameFieldStringValue:[baseName stringByAppendingPathExtension:extension]];
    if ([panel runModal] != NSOKButton) return;
    NSString *outputPath = [[panel URL] path];
    NSUInteger maximumDimension = [[[_sizePopup selectedItem] representedObject] unsignedIntegerValue];
    CGFloat quality = [_qualitySlider doubleValue] / 100.0;
    NSString *sourcePath = [_sourcePath copy];
    NSString *outputFormat = [format copy];
    _processing = YES;
    [_saveButton setEnabled:NO];
    [_spinner startAnimation:nil];
    [_statusField setStringValue:[_hostContext localizedStringForKey:@"mediaWorkbench.processing"
                                                             fallback:@"Processing image..."]];
    __block TGMediaWorkbenchViewController *blockSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [TGMediaWorkbenchProcessor processImageAtPath:sourcePath
                                                         outputPath:outputPath
                                                             format:outputFormat
                                                   maximumDimension:maximumDimension
                                                            quality:quality
                                                              error:&error];
        NSString *message = success
            ? [blockSelf->_hostContext localizedStringForKey:@"mediaWorkbench.saved"
                                                     fallback:@"The processed image was saved."]
            : [error localizedDescription];
        [message retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            blockSelf->_processing = NO;
            [blockSelf->_spinner stopAnimation:nil];
            [blockSelf->_saveButton setEnabled:YES];
            [blockSelf->_statusField setStringValue:(message ? message : @"")];
            [message release];
            [sourcePath release];
            [outputFormat release];
        });
        [pool drain];
    });
}

- (void)qualityChanged:(id)sender {
    (void)sender;
    [_qualityField setStringValue:[NSString stringWithFormat:@"%@: %.0f%%",
        [_hostContext localizedStringForKey:@"mediaWorkbench.quality" fallback:@"JPEG quality"],
        [_qualitySlider doubleValue]]];
}

- (void)dealloc {
    [_hostContext release];
    [_sourcePath release];
    [_titleField release];
    [_hintField release];
    [_panelView release];
    [_previewView release];
    [_fileField release];
    [_chooseButton release];
    [_formatPopup release];
    [_sizePopup release];
    [_qualitySlider release];
    [_qualityField release];
    [_saveButton release];
    [_statusField release];
    [_spinner release];
    [super dealloc];
}

@end
