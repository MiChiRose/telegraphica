#import <Cocoa/Cocoa.h>
#import "../Host/TGWorkshopCoordinator.h"
#import "TGWorkshopModuleCardView.h"

@class TGWorkshopViewController;

@protocol TGWorkshopViewControllerDelegate <NSObject>
- (void)workshopViewControllerDidRequestClose:(TGWorkshopViewController *)viewController;
@optional
- (void)workshopViewController:(TGWorkshopViewController *)viewController
       didChangeActiveModule:(BOOL)active;
@end

@interface TGWorkshopViewController : NSViewController
    <TGWorkshopCoordinatorDelegate, TGWorkshopModuleCardViewDelegate> {
@private
    id<TGWorkshopViewControllerDelegate> _delegate;
    TGWorkshopCoordinator *_coordinator;
    NSButton *_backButton;
    NSTextField *_titleField;
    NSTextField *_categoryField;
    NSTextField *_statusField;
    NSArray *_modeButtons;
    NSScrollView *_scrollView;
    NSView *_contentView;
    NSView *_moduleContainerView;
    NSViewController *_activeModuleViewController;
    NSString *_selectedMode;
    NSMutableDictionary *_progressByIdentifier;
    NSMutableDictionary *_errorsByIdentifier;
    NSMutableDictionary *_installStartDatesByIdentifier;
    BOOL _started;
}

@property(nonatomic, assign) id<TGWorkshopViewControllerDelegate> delegate;
@property(nonatomic, retain, readonly) TGWorkshopCoordinator *coordinator;

- (id)initWithCoordinator:(TGWorkshopCoordinator *)coordinator;
- (void)startIfNeeded;
- (BOOL)hasActiveModule;
- (void)requestCloseActiveModuleOrWorkshop;
- (void)refreshLocalization;
- (void)refreshTheme;

@end
