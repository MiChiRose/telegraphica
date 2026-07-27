#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGBotCommandPanelView : NSView <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;

- (id)initWithFrame:(NSRect)frame client:(TGTDLibClient *)client;
- (void)loadCommandsForUserID:(NSNumber *)userID;
- (void)clearCommands;

@end
