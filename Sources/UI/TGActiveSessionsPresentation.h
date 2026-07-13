#import <Cocoa/Cocoa.h>

typedef NSString * (^TGActiveSessionsLocalizationBlock)(NSString *key);

@interface TGActiveSessionsPresentation : NSObject

+ (NSString *)statusTextForSummary:(NSDictionary *)summary
                          localize:(TGActiveSessionsLocalizationBlock)localize;

+ (NSAttributedString *)detailsTextForSummary:(NSDictionary *)summary
                                  languageCode:(NSString *)languageCode
                                      localize:(TGActiveSessionsLocalizationBlock)localize
                                     textColor:(NSColor *)textColor
                                    mutedColor:(NSColor *)mutedColor;

@end
