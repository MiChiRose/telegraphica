#import <Cocoa/Cocoa.h>

@class TGWorkshopCatalogEntry;
@class TGWorkshopModuleCardView;

typedef enum {
    TGWorkshopModuleCardActionInstall = 1,
    TGWorkshopModuleCardActionOpen = 2,
    TGWorkshopModuleCardActionUpdate = 3,
    TGWorkshopModuleCardActionRemove = 4,
    TGWorkshopModuleCardActionRetry = 5
} TGWorkshopModuleCardAction;

@protocol TGWorkshopModuleCardViewDelegate <NSObject>
- (void)workshopModuleCardView:(TGWorkshopModuleCardView *)cardView
                requestedAction:(TGWorkshopModuleCardAction)action
                          entry:(TGWorkshopCatalogEntry *)entry;
@end

@interface TGWorkshopModuleCardView : NSView {
@private
    id<TGWorkshopModuleCardViewDelegate> _delegate;
    TGWorkshopCatalogEntry *_entry;
    NSDictionary *_installedRecord;
    NSTextField *_nameField;
    NSTextField *_descriptionField;
    NSTextField *_detailsField;
    NSTextField *_statusField;
    NSProgressIndicator *_progressIndicator;
    NSImageView *_successImageView;
    NSButton *_primaryButton;
    NSButton *_removeButton;
    BOOL _busy;
    double _progress;
    NSString *_errorMessage;
    BOOL _showingSuccess;
}

@property(nonatomic, assign) id<TGWorkshopModuleCardViewDelegate> delegate;
@property(nonatomic, retain) TGWorkshopCatalogEntry *entry;

- (void)configureWithInstalledRecord:(NSDictionary *)installedRecord
                                busy:(BOOL)busy
                            progress:(double)progress
                        errorMessage:(NSString *)errorMessage;
- (void)refreshTheme;
- (void)refreshLocalization;
- (void)updateProgress:(double)progress;
- (void)showInstallSuccess;
- (void)beginRemovalAnimation;

@end
