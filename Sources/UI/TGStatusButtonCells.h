#import <Cocoa/Cocoa.h>

void TGDrawMutedSpeakerIconInRect(NSRect iconRect, NSColor *color, BOOL flipped);

@interface TGNavigationButtonCell : NSButtonCell {
    NSString *_badgeText;
    BOOL _iconOnly;
}
@property (nonatomic, copy) NSString *badgeText;
@property (nonatomic, assign) BOOL iconOnly;
@end

@interface TGDrawerButtonCell : NSButtonCell {
    BOOL _backStyle;
}
@property (nonatomic, assign) BOOL backStyle;
@end

@interface TGSendButtonCell : NSButtonCell
@end

@interface TGAttachButtonCell : NSButtonCell
@end

@interface TGComposerSymbolButtonCell : NSButtonCell
@end

@interface TGHeaderIconButtonCell : NSButtonCell
@end

@interface TGPrimaryTextButtonCell : NSButtonCell
@end

@interface TGSecondaryTextButtonCell : NSButtonCell
@end

@interface TGMediaZoomButtonCell : NSButtonCell
@end

@interface TGMediaPlaybackButtonCell : NSButtonCell
@end

@interface TGSettingsListButtonCell : NSButtonCell
@end

@interface TGStickerPickerButtonCell : NSButtonCell
@end

@interface TGStickerPickerTabButtonCell : NSButtonCell
@end
