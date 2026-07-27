#import <Cocoa/Cocoa.h>

#import "TGStatusViewCells.h"

@interface TGContactProfileView : TGGroupedCardView {
    NSDictionary *_contact;
    id _avatarView;
    NSTextField *_nameField;
    NSTextField *_statusField;
    NSTextField *_usernameTitleField;
    NSTextField *_usernameValueField;
    NSTextField *_phoneTitleField;
    NSTextField *_phoneValueField;
    NSTextField *_bioTitleField;
    NSTextField *_bioValueField;
    NSTextField *_hintField;
}

- (void)showPlaceholder;
- (void)showLoadingForContact:(NSDictionary *)contact;
- (void)showContact:(NSDictionary *)contact;
- (void)showError:(NSString *)message contact:(NSDictionary *)contact;
- (void)refreshThemeAppearance;

@end
