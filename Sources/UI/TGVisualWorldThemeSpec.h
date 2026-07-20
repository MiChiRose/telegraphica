#import <Cocoa/Cocoa.h>

typedef enum {
    TGVisualWorldDecorationMacintoshDesktop = 1,
    TGVisualWorldDecorationBlueprint = 2,
    TGVisualWorldDecorationNotebook = 3,
    TGVisualWorldDecorationCRTTerminal = 4,
    TGVisualWorldDecorationNewspaper = 5,
    TGVisualWorldDecorationOldComputer = 6,
    TGVisualWorldDecorationGreenhouse = 7,
    TGVisualWorldDecorationSpaceTerminal = 8,
    TGVisualWorldDecorationVinylStudio = 9,
    TGVisualWorldDecorationPostcard = 10
} TGVisualWorldDecorationMode;

@interface TGVisualWorldThemeSpec : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *themeDescription;
@property (nonatomic, assign) NSUInteger backgroundHex;
@property (nonatomic, assign) NSUInteger panelHex;
@property (nonatomic, assign) NSUInteger surfaceHex;
@property (nonatomic, assign) NSUInteger incomingHex;
@property (nonatomic, assign) NSUInteger outgoingHex;
@property (nonatomic, assign) NSUInteger primaryHex;
@property (nonatomic, assign) NSUInteger secondaryHex;
@property (nonatomic, assign) NSUInteger textHex;
@property (nonatomic, assign) NSUInteger mutedHex;
@property (nonatomic, assign) NSUInteger borderHex;
@property (nonatomic, assign) NSUInteger warmHex;
@property (nonatomic, assign) TGVisualWorldDecorationMode decorationMode;
@property (nonatomic, assign) BOOL darkCards;

@end

NSArray *TGVisualWorldThemeIdentifiers(void);
TGVisualWorldThemeSpec *TGVisualWorldThemeSpecForIdentifier(NSString *identifier);
BOOL TGVisualWorldThemeIdentifierIsValid(NSString *identifier);
void TGVisualWorldDrawWindowBackground(NSString *identifier, NSRect rect);
void TGVisualWorldDrawSurfacePattern(NSString *identifier, NSRect rect, CGFloat alpha);
