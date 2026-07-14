#import <Cocoa/Cocoa.h>

void TGDrawMutedSpeakerIconInRect(NSRect iconRect, NSColor *color, BOOL flipped);

@interface TGNavigationButtonCell : NSButtonCell {
    NSString *_badgeText;
}
@property (nonatomic, copy) NSString *badgeText;
@end

@interface TGDrawerButtonCell : NSButtonCell
@end

@interface TGSendButtonCell : NSButtonCell
@end

@interface TGAttachButtonCell : NSButtonCell
@end

@interface TGComposerSymbolButtonCell : NSButtonCell
@end

@interface TGHeaderIconButtonCell : NSButtonCell
@end

@interface TGMediaZoomButtonCell : NSButtonCell
@end

@interface TGMediaPlaybackButtonCell : NSButtonCell
@end

@interface TGSettingsListButtonCell : NSButtonCell
@end
