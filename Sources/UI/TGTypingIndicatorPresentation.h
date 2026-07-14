#import <Foundation/Foundation.h>

NSString *TGTypingActionTextForSummary(NSDictionary *summary);
NSString *TGTypingSenderNameForSummary(NSDictionary *summary,
                                       NSString *selectedChatTypeSummary,
                                       NSString *selectedChatTitle,
                                       NSArray *messageItems);
NSString *TGTypingIndicatorTextForSummary(NSDictionary *summary,
                                          NSString *selectedChatTypeSummary,
                                          NSString *selectedChatTitle,
                                          NSArray *messageItems);
