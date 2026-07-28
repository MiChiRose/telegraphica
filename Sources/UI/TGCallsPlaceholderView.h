#import <Cocoa/Cocoa.h>

#import "TGStatusViewCells.h"

@class TGCallCoordinator;
@class TGTDLibClient;

@interface TGCallsPlaceholderView : TGPanelView <NSTableViewDataSource, NSTableViewDelegate>
- (id)initWithFrame:(NSRect)frame client:(TGTDLibClient *)client coordinator:(TGCallCoordinator *)coordinator;
- (void)refreshData;
- (void)refreshLocalizedText;
- (void)refreshThemeAppearance;
@end
