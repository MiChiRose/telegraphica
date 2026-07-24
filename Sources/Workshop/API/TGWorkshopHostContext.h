#import <Cocoa/Cocoa.h>

@protocol TGWorkshopHostContext <NSObject>

- (NSString *)languageCode;
- (NSString *)activeThemeIdentifier;
- (NSDictionary *)themeColors;
- (NSFont *)interfaceFontOfSize:(CGFloat)size bold:(BOOL)bold;
- (NSString *)localizedStringForKey:(NSString *)key fallback:(NSString *)fallback;
- (NSURL *)moduleDataDirectoryURL;
- (NSDictionary *)diagnosticSnapshot;
- (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (void)requestModuleClose;

@end
