#import "TGContactProfileView.h"

#import "TGLocalization.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

static NSTextField *TGContactProfileLabel(NSRect frame, NSFont *font, NSInteger alignment) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setAlignment:alignment];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return field;
}

static NSString *TGContactProfilePresence(NSDictionary *contact) {
    if ([[contact objectForKey:@"is_bot"] boolValue]) {
        return TGLoc(@"contacts.bot");
    }
    if ([[contact objectForKey:@"is_online"] boolValue]) {
        return TGLoc(@"contacts.online");
    }
    id wasOnline = [contact objectForKey:@"was_online"];
    if ([wasOnline respondsToSelector:@selector(doubleValue)] && [wasOnline doubleValue] > 0.0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[wasOnline doubleValue]];
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        return [NSString stringWithFormat:TGLoc(@"contacts.lastSeen"), [formatter stringFromDate:date]];
    }
    return @"";
}

@implementation TGContactProfileView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        _avatarView = [[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(0, 0, 72, 72)];
        [self addSubview:_avatarView];
        _nameField = [TGContactProfileLabel(NSZeroRect, [NSFont boldSystemFontOfSize:16.0], NSCenterTextAlignment) retain];
        _statusField = [TGContactProfileLabel(NSZeroRect, [NSFont systemFontOfSize:11.0], NSCenterTextAlignment) retain];
        _usernameTitleField = [TGContactProfileLabel(NSZeroRect, [NSFont boldSystemFontOfSize:11.0], NSLeftTextAlignment) retain];
        _usernameValueField = [TGContactProfileLabel(NSZeroRect, [NSFont systemFontOfSize:12.0], NSLeftTextAlignment) retain];
        _phoneTitleField = [TGContactProfileLabel(NSZeroRect, [NSFont boldSystemFontOfSize:11.0], NSLeftTextAlignment) retain];
        _phoneValueField = [TGContactProfileLabel(NSZeroRect, [NSFont systemFontOfSize:12.0], NSLeftTextAlignment) retain];
        _bioTitleField = [TGContactProfileLabel(NSZeroRect, [NSFont boldSystemFontOfSize:11.0], NSLeftTextAlignment) retain];
        _bioValueField = [TGContactProfileLabel(NSZeroRect, [NSFont systemFontOfSize:12.0], NSLeftTextAlignment) retain];
        [[_bioValueField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        _hintField = [TGContactProfileLabel(NSZeroRect, [NSFont systemFontOfSize:12.0], NSCenterTextAlignment) retain];
        [[_hintField cell] setLineBreakMode:NSLineBreakByWordWrapping];

        [self addSubview:_nameField];
        [self addSubview:_statusField];
        [self addSubview:_usernameTitleField];
        [self addSubview:_usernameValueField];
        [self addSubview:_phoneTitleField];
        [self addSubview:_phoneValueField];
        [self addSubview:_bioTitleField];
        [self addSubview:_bioValueField];
        [self addSubview:_hintField];
        [self showPlaceholder];
        [self refreshThemeAppearance];
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    (void)oldSize;
    NSRect bounds = [self bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat inset = 20.0;
    [_avatarView setFrame:NSMakeRect(floor((width - 72.0) / 2.0), height - 100.0, 72.0, 72.0)];
    [_nameField setFrame:NSMakeRect(inset, height - 130.0, MAX(80.0, width - inset * 2.0), 22.0)];
    [_statusField setFrame:NSMakeRect(inset, height - 150.0, MAX(80.0, width - inset * 2.0), 18.0)];

    CGFloat rowY = height - 196.0;
    [_usernameTitleField setFrame:NSMakeRect(inset, rowY, 84.0, 17.0)];
    [_usernameValueField setFrame:NSMakeRect(inset + 88.0, rowY, MAX(60.0, width - inset * 2.0 - 88.0), 17.0)];
    rowY -= 32.0;
    [_phoneTitleField setFrame:NSMakeRect(inset, rowY, 84.0, 17.0)];
    [_phoneValueField setFrame:NSMakeRect(inset + 88.0, rowY, MAX(60.0, width - inset * 2.0 - 88.0), 17.0)];
    rowY -= 34.0;
    [_bioTitleField setFrame:NSMakeRect(inset, rowY, MAX(80.0, width - inset * 2.0), 17.0)];
    [_bioValueField setFrame:NSMakeRect(inset, 20.0, MAX(80.0, width - inset * 2.0), MAX(38.0, rowY - 24.0))];
    [_hintField setFrame:NSMakeRect(inset, floor((height - 54.0) / 2.0), MAX(80.0, width - inset * 2.0), 54.0)];
}

- (void)setDetailFieldsHidden:(BOOL)hidden {
    [_avatarView setHidden:hidden];
    [_nameField setHidden:hidden];
    [_statusField setHidden:hidden];
    [_usernameTitleField setHidden:hidden];
    [_usernameValueField setHidden:hidden];
    [_phoneTitleField setHidden:hidden];
    [_phoneValueField setHidden:hidden];
    [_bioTitleField setHidden:hidden];
    [_bioValueField setHidden:hidden];
}

- (void)showPlaceholder {
    [_contact release];
    _contact = nil;
    [self setDetailFieldsHidden:YES];
    [_hintField setHidden:NO];
    [_hintField setStringValue:TGLoc(@"contacts.selectHint")];
}

- (void)showLoadingForContact:(NSDictionary *)contact {
    [self showContact:contact];
    [_statusField setStringValue:TGLoc(@"contacts.profileLoading")];
}

- (void)showContact:(NSDictionary *)contact {
    [_contact release];
    _contact = [contact copy];
    if (!_contact) {
        [self showPlaceholder];
        return;
    }
    [self setDetailFieldsHidden:NO];
    [_hintField setHidden:YES];
    NSString *displayName = [_contact objectForKey:@"display_name"];
    NSString *avatarPath = [_contact objectForKey:@"avatar_local_path"];
    if ([avatarPath length] == 0) {
        avatarPath = [_contact objectForKey:@"avatar_path"];
    }
    [(TGProfileAvatarView *)_avatarView setDisplayName:([displayName length] > 0 ? displayName : @"?")];
    [(TGProfileAvatarView *)_avatarView setAvatarLocalPath:avatarPath];
    [_nameField setStringValue:([displayName length] > 0 ? displayName : @"?")];
    [_statusField setStringValue:TGContactProfilePresence(_contact)];
    [_usernameTitleField setStringValue:TGLoc(@"profile.username")];
    [_phoneTitleField setStringValue:TGLoc(@"profile.phone")];
    [_bioTitleField setStringValue:TGLoc(@"profile.about")];

    NSString *username = [_contact objectForKey:@"username"];
    NSString *phone = [_contact objectForKey:@"phone_number"];
    NSString *bio = [_contact objectForKey:@"bio"];
    NSString *phoneValue = [phone hasPrefix:@"+"] ? phone : [NSString stringWithFormat:@"+%@", phone];
    [_usernameValueField setStringValue:([username length] > 0 ? [NSString stringWithFormat:@"@%@", username] : TGLoc(@"contacts.notAvailable"))];
    [_phoneValueField setStringValue:([phone length] > 0 ? phoneValue : TGLoc(@"contacts.notAvailable"))];
    [_bioValueField setStringValue:([bio length] > 0 ? bio : TGLoc(@"contacts.notAvailable"))];
    [self resizeSubviewsWithOldSize:NSZeroSize];
}

- (void)showError:(NSString *)message contact:(NSDictionary *)contact {
    [self showContact:contact];
    [_statusField setStringValue:([message length] > 0 ? message : TGLoc(@"contacts.profileError"))];
}

- (void)refreshThemeAppearance {
    [_nameField setTextColor:TGClassicCardInkColor()];
    [_statusField setTextColor:TGClassicCardMutedInkColor()];
    [_usernameTitleField setTextColor:TGClassicCardMutedInkColor()];
    [_phoneTitleField setTextColor:TGClassicCardMutedInkColor()];
    [_bioTitleField setTextColor:TGClassicCardMutedInkColor()];
    [_usernameValueField setTextColor:TGClassicCardInkColor()];
    [_phoneValueField setTextColor:TGClassicCardInkColor()];
    [_bioValueField setTextColor:TGClassicCardInkColor()];
    [_hintField setTextColor:TGClassicCardMutedInkColor()];
    [self setNeedsDisplay:YES];
}

- (void)dealloc {
    [_contact release];
    [_avatarView release];
    [_nameField release];
    [_statusField release];
    [_usernameTitleField release];
    [_usernameValueField release];
    [_phoneTitleField release];
    [_phoneValueField release];
    [_bioTitleField release];
    [_bioValueField release];
    [_hintField release];
    [super dealloc];
}

@end
