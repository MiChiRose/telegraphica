#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "TGMediaFileActions.h"
#include <stdio.h>

NSString *TGLoc(NSString *key) { return key; }
static BOOL TGCurrent, TGInvalidateInModal;
static NSUInteger TGModalCount;
static NSString *TGDestination;
@interface TGSavePanelProbe : NSObject
- (void)setNameFieldStringValue:(NSString *)name;
- (NSInteger)runModal;
- (NSURL *)URL;
@end
@implementation TGSavePanelProbe
- (void)setNameFieldStringValue:(NSString *)name { (void)name; }
- (NSInteger)runModal { TGModalCount++; if (TGInvalidateInModal) { TGCurrent = NO; } return NSFileHandlingPanelOKButton; }
- (NSURL *)URL { return [NSURL fileURLWithPath:TGDestination]; }
@end
static id TGSavePanel(id receiver, SEL selector) {
    (void)receiver; (void)selector; return [[[TGSavePanelProbe alloc] init] autorelease];
}
static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Guarded Save panel probe failed: %s\n", message); exit(1); }
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *source = [directory stringByAppendingPathComponent:@"source.zip"];
    TGDestination = [[directory stringByAppendingPathComponent:@"destination.zip"] copy];
    [@"source bytes" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"existing destination" writeToFile:TGDestination atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    Class meta = object_getClass([NSSavePanel class]);
    Method method = class_getClassMethod([NSSavePanel class], @selector(savePanel));
    IMP original = method_getImplementation(method);
    class_replaceMethod(meta, @selector(savePanel), (IMP)TGSavePanel, method_getTypeEncoding(method));

    TGCurrent = YES; TGInvalidateInModal = YES;
    NSString *saved = [TGMediaFileActions saveCopyOfFileAtPath:source suggestedFileName:@"archive.zip"
                                            shouldContinue:^BOOL { return TGCurrent; } error:NULL];
    TGAssert(saved == nil && TGModalCount == 1, "cancel during nested modal rejects destination export");
    TGAssert([[NSString stringWithContentsOfFile:TGDestination encoding:NSUTF8StringEncoding error:NULL]
              isEqualToString:@"existing destination"], "cancelled Save As cannot replace existing destination");
    TGAssert([[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL].count == 2,
             "cancelled Save As creates no temporary copy");

    TGCurrent = NO; TGInvalidateInModal = NO;
    saved = [TGMediaFileActions saveCopyOfFileAtPath:source suggestedFileName:@"archive.zip"
                                     shouldContinue:^BOOL { return TGCurrent; } error:NULL];
    TGAssert(saved == nil && TGModalCount == 1, "stale request cannot open Save panel");

    [[NSFileManager defaultManager] removeItemAtPath:TGDestination error:NULL];
    TGCurrent = YES;
    saved = [TGMediaFileActions saveCopyOfFileAtPath:source suggestedFileName:@"archive.zip"
                                     shouldContinue:^BOOL { return TGCurrent; } error:NULL];
    TGAssert([saved isEqualToString:TGDestination] && TGModalCount == 2, "current guarded request saves selected destination");
    TGAssert([[NSString stringWithContentsOfFile:TGDestination encoding:NSUTF8StringEncoding error:NULL]
              isEqualToString:@"source bytes"], "guarded save copies complete source");

    [[NSFileManager defaultManager] removeItemAtPath:TGDestination error:NULL];
    saved = [TGMediaFileActions saveCopyOfFileAtPath:source suggestedFileName:@"archive.zip" error:NULL];
    TGAssert([saved isEqualToString:TGDestination] && TGModalCount == 3, "existing unguarded API remains compatible");
    class_replaceMethod(meta, @selector(savePanel), original, method_getTypeEncoding(method));
    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL]; [TGDestination release];
    printf("Guarded Save panel production helper probe: PASS\n"); [pool drain]; return 0;
}
