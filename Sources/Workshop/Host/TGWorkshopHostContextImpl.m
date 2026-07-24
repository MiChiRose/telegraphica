#import "TGWorkshopHostContextImpl.h"
#import "TGWorkshopPaths.h"
#import "../../UI/TGLocalization.h"
#import "../../UI/TGTheme.h"

@implementation TGWorkshopHostContextImpl

- (id)initWithModuleIdentifier:(NSString *)moduleIdentifier
                       delegate:(id<TGWorkshopHostContextDelegate>)delegate {
    self = [super init];
    if (self) {
        _moduleIdentifier = [moduleIdentifier copy];
        _delegate = delegate;
    }
    return self;
}

- (NSString *)languageCode {
    return TGLanguageCode();
}

- (NSString *)activeThemeIdentifier {
    return TGCurrentThemeIdentifier();
}

- (NSDictionary *)themeColors {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            TGClassicPanelBottomColor(), @"background",
            TGClassicTablePaperColor(), @"surface",
            TGClassicInkColor(), @"text",
            TGClassicMutedInkColor(), @"muted_text",
            TGClassicSelectedRowColor(), @"accent",
            TGClassicSelectedRowTextColor(), @"accent_text",
            TGClassicPanelStrokeColor(), @"stroke",
            nil];
}

- (NSFont *)interfaceFontOfSize:(CGFloat)size bold:(BOOL)bold {
    return bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
}

- (NSString *)localizedStringForKey:(NSString *)key fallback:(NSString *)fallback {
    NSString *localized = TGLoc(key);
    if ([localized length] == 0 || [localized isEqualToString:key]) {
        return fallback ? fallback : key;
    }
    return localized;
}

- (NSURL *)moduleDataDirectoryURL {
    NSString *path = TGWorkshopDataDirectoryForModuleIdentifier(_moduleIdentifier);
    TGWorkshopEnsureDirectory(path, NULL);
    return path ? [NSURL fileURLWithPath:path isDirectory:YES] : nil;
}

- (NSDictionary *)diagnosticSnapshot {
    if ([_delegate respondsToSelector:@selector(workshopHostContextDiagnosticSnapshot)]) {
        NSDictionary *snapshot = [_delegate workshopHostContextDiagnosticSnapshot];
        return [snapshot isKindOfClass:[NSDictionary class]] ? snapshot : [NSDictionary dictionary];
    }
    return [NSDictionary dictionary];
}

- (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message {
    if ([_delegate respondsToSelector:@selector(workshopHostContextRequestedNotificationWithTitle:message:)]) {
        [_delegate workshopHostContextRequestedNotificationWithTitle:title message:message];
    }
}

- (void)requestModuleClose {
    if ([_delegate respondsToSelector:@selector(workshopHostContextRequestedClose)]) {
        [_delegate workshopHostContextRequestedClose];
    }
}

- (void)dealloc {
    [_moduleIdentifier release];
    [super dealloc];
}

@end
