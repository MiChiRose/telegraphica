#import <Cocoa/Cocoa.h>

@class TGVideoNoteRecorderWindowController;

@protocol TGVideoNoteRecorderWindowControllerDelegate <NSObject>
- (void)videoNoteRecorder:(TGVideoNoteRecorderWindowController *)recorder
     didFinishVideoAtPath:(NSString *)path;
- (void)videoNoteRecorderDidCancel:(TGVideoNoteRecorderWindowController *)recorder;
@end

@interface TGVideoNoteRecorderWindowController : NSWindowController

@property (nonatomic, assign) id<TGVideoNoteRecorderWindowControllerDelegate> delegate;

- (void)presentWithMicrophoneEnabled:(BOOL)microphoneEnabled;

@end
