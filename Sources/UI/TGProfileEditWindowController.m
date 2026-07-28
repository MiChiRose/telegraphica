#import "TGProfileEditWindowController.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"
#import "TGLocalization.h"

@interface TGProfileEditBackgroundView : NSView
@end

@implementation TGProfileEditBackgroundView
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    TGThemeDrawWindowBackgroundInRect([self bounds], [self isFlipped]);
}
@end

@interface TGProfileEditWindowController () {
    id<TGProfileEditWindowControllerDelegate> _delegate;
    NSTextField *_firstNameField;
    NSTextField *_lastNameField;
    NSTextField *_usernameField;
    NSTextField *_bioField;
    NSTextField *_errorField;
    NSButton *_photoButton;
    NSButton *_saveButton;
    NSButton *_cancelButton;
}
- (void)chooseProfilePhoto:(id)sender;
- (void)saveProfile:(id)sender;
- (void)cancelProfileEdit:(id)sender;
@end

@implementation TGProfileEditWindowController

@synthesize delegate = _delegate;

static NSTextField *TGProfileEditLabel(NSString *title, NSRect frame) {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont systemFontOfSize:12.0]];
    [label setTextColor:TGClassicMutedInkColor()];
    [label setStringValue:title ? title : @""];
    return label;
}

static NSTextField *TGProfileEditInput(NSRect frame) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setFont:[NSFont systemFontOfSize:13.0]];
    [field setTextColor:TGClassicInkColor()];
    [field setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.94]];
    [field setBezeled:YES];
    [field setBezelStyle:NSTextFieldRoundedBezel];
    [field setFocusRingType:NSFocusRingTypeNone];
    return field;
}

static NSString *TGPreparedProfilePhotoPath(NSString *sourcePath, NSError **error) {
    NSImage *sourceImage = [[[NSImage alloc] initWithContentsOfFile:sourcePath] autorelease];
    NSData *tiffData = [sourceImage TIFFRepresentation];
    NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:0.9]
                                                            forKey:NSImageCompressionFactor];
    NSData *jpegData = [bitmap representationUsingType:NSJPEGFileType properties:properties];
    if ([jpegData length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"Telegraphica.ProfilePhoto"
                                         code:1
                                     userInfo:[NSDictionary dictionaryWithObject:TGLoc(@"profile.edit.photo.invalid")
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheRoot = ([cachePaths count] > 0)
        ? [cachePaths objectAtIndex:0]
        : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *directory = [cacheRoot stringByAppendingPathComponent:@"Telegraphica/ProfilePhotoUploads"];
    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&directoryError]) {
        if (error) {
            *error = directoryError;
        }
        return nil;
    }

    NSString *fileName = [NSString stringWithFormat:@"profile-%@.jpg",
                          [[NSProcessInfo processInfo] globallyUniqueString]];
    NSString *destinationPath = [directory stringByAppendingPathComponent:fileName];
    if (![jpegData writeToFile:destinationPath options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    return destinationPath;
}

- (id)init {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 470.0, 450.0)
                                                   styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO] autorelease];
    [window setTitle:TGLoc(@"profile.edit.title")];
    [window setReleasedWhenClosed:NO];
    self = [super initWithWindow:window];
    if (self) {
        TGProfileEditBackgroundView *contentView = [[[TGProfileEditBackgroundView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 470.0, 450.0)] autorelease];
        [window setContentView:contentView];

        TGGroupedCardView *editorCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20.0, 18.0, 430.0, 374.0)] autorelease];
        [contentView addSubview:editorCard];

        NSTextField *titleField = TGProfileEditLabel(TGLoc(@"profile.edit.title"), NSMakeRect(28.0, 404.0, 414.0, 24.0));
        [titleField setFont:[NSFont boldSystemFontOfSize:18.0]];
        [titleField setTextColor:TGClassicHeaderTextColor(1.0)];
        [contentView addSubview:titleField];

        [contentView addSubview:TGProfileEditLabel(TGLoc(@"profile.edit.photo"), NSMakeRect(30.0, 363.0, 188.0, 18.0))];
        _photoButton = [[NSButton alloc] initWithFrame:NSMakeRect(248.0, 354.0, 194.0, 30.0)];
        [_photoButton setTitle:TGLoc(@"profile.edit.photo.choose")];
        [_photoButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"profile.edit.photo.choose")] autorelease]];
        [_photoButton setTarget:self];
        [_photoButton setAction:@selector(chooseProfilePhoto:)];
        [contentView addSubview:_photoButton];

        [contentView addSubview:TGProfileEditLabel(TGLoc(@"profile.edit.firstName"), NSMakeRect(30.0, 305.0, 190.0, 18.0))];
        [contentView addSubview:TGProfileEditLabel(TGLoc(@"profile.edit.lastName"), NSMakeRect(250.0, 305.0, 190.0, 18.0))];
        _firstNameField = [TGProfileEditInput(NSMakeRect(28.0, 273.0, 194.0, 28.0)) retain];
        _lastNameField = [TGProfileEditInput(NSMakeRect(248.0, 273.0, 194.0, 28.0)) retain];
        [contentView addSubview:_firstNameField];
        [contentView addSubview:_lastNameField];

        [contentView addSubview:TGProfileEditLabel(TGLoc(@"profile.edit.username"), NSMakeRect(30.0, 235.0, 412.0, 18.0))];
        _usernameField = [TGProfileEditInput(NSMakeRect(28.0, 203.0, 414.0, 28.0)) retain];
        [[_usernameField cell] setPlaceholderString:@"username"];
        [contentView addSubview:_usernameField];

        [contentView addSubview:TGProfileEditLabel(TGLoc(@"profile.edit.bio"), NSMakeRect(30.0, 165.0, 412.0, 18.0))];
        _bioField = [TGProfileEditInput(NSMakeRect(28.0, 93.0, 414.0, 68.0)) retain];
        [[_bioField cell] setUsesSingleLineMode:NO];
        [[_bioField cell] setWraps:YES];
        [[_bioField cell] setScrollable:YES];
        [contentView addSubview:_bioField];

        _errorField = [TGProfileEditLabel(@"", NSMakeRect(30.0, 65.0, 412.0, 20.0)) retain];
        [_errorField setTextColor:[NSColor colorWithCalibratedRed:0.76 green:0.12 blue:0.10 alpha:1.0]];
        [[_errorField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [contentView addSubview:_errorField];

        _cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(232.0, 24.0, 100.0, 30.0)];
        [_cancelButton setTitle:TGLoc(@"cancel")];
        [_cancelButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"cancel")] autorelease]];
        [_cancelButton setTarget:self];
        [_cancelButton setAction:@selector(cancelProfileEdit:)];
        [contentView addSubview:_cancelButton];

        _saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(342.0, 24.0, 100.0, 30.0)];
        [_saveButton setTitle:TGLoc(@"save")];
        [_saveButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"save")] autorelease]];
        [_saveButton setTarget:self];
        [_saveButton setAction:@selector(saveProfile:)];
        [contentView addSubview:_saveButton];
    }
    return self;
}

- (void)dealloc {
    [_firstNameField release];
    [_lastNameField release];
    [_usernameField release];
    [_bioField release];
    [_errorField release];
    [_photoButton release];
    [_saveButton release];
    [_cancelButton release];
    [super dealloc];
}

- (void)configureWithFirstName:(NSString *)firstName
                      lastName:(NSString *)lastName
                      username:(NSString *)username
                           bio:(NSString *)bio {
    [_firstNameField setStringValue:firstName ? firstName : @""];
    [_lastNameField setStringValue:lastName ? lastName : @""];
    [_usernameField setStringValue:username ? username : @""];
    [_bioField setStringValue:bio ? bio : @""];
    [self showErrorMessage:nil];
    [self setSaving:NO];
}

- (void)setSaving:(BOOL)saving {
    [_firstNameField setEnabled:!saving];
    [_lastNameField setEnabled:!saving];
    [_usernameField setEnabled:!saving];
    [_bioField setEnabled:!saving];
    [_photoButton setEnabled:!saving];
    [_saveButton setEnabled:!saving];
    [_cancelButton setEnabled:!saving];
}

- (void)showErrorMessage:(NSString *)message {
    [_errorField setStringValue:message ? message : @""];
}

- (void)chooseProfilePhoto:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", nil]];
    if ([panel runModal] != NSOKButton) {
        return;
    }
    NSURL *selectedURL = ([[panel URLs] count] > 0) ? [[panel URLs] objectAtIndex:0] : nil;
    NSError *preparationError = nil;
    NSString *preparedPath = TGPreparedProfilePhotoPath([selectedURL path], &preparationError);
    if ([preparedPath length] == 0) {
        NSString *message = [preparationError localizedDescription];
        [self showErrorMessage:([message length] > 0 ? message : TGLoc(@"profile.edit.photo.invalid"))];
        return;
    }
    [self showErrorMessage:nil];
    if (_delegate && [_delegate respondsToSelector:@selector(profileEditWindowController:didRequestSetPhotoAtPath:)]) {
        [_delegate profileEditWindowController:self didRequestSetPhotoAtPath:preparedPath];
    }
}

- (void)saveProfile:(id)sender {
    (void)sender;
    NSString *firstName = [[_firstNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [[_lastNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *username = [[_usernameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *bio = [[_bioField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([username hasPrefix:@"@"]) {
        username = [username substringFromIndex:1];
    }
    if ([firstName length] == 0) {
        [self showErrorMessage:TGLoc(@"profile.edit.firstNameRequired")];
        [[self window] makeFirstResponder:_firstNameField];
        return;
    }
    if (_delegate && [_delegate respondsToSelector:@selector(profileEditWindowController:didRequestSaveFirstName:lastName:username:bio:)]) {
        [_delegate profileEditWindowController:self
                       didRequestSaveFirstName:firstName
                                      lastName:lastName
                                      username:username
                                           bio:bio];
    }
}

- (void)cancelProfileEdit:(id)sender {
    (void)sender;
    [[self window] orderOut:self];
}

@end
