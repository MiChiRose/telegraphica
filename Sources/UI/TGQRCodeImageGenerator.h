#import <AppKit/AppKit.h>

@interface TGQRCodeImageGenerator : NSObject

+ (NSImage *)imageForString:(NSString *)string maximumSide:(CGFloat)maximumSide;

@end
