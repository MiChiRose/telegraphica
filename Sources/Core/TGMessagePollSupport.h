#import <Foundation/Foundation.h>

extern NSString * const TGMessagePollQuestionKey;
extern NSString * const TGMessagePollOptionsKey;
extern NSString * const TGMessagePollTotalVoterCountKey;
extern NSString * const TGMessagePollClosedKey;
extern NSString * const TGMessagePollAnonymousKey;
extern NSString * const TGMessagePollMultipleChoiceKey;
extern NSString * const TGMessagePollQuizKey;
extern NSString * const TGMessagePollIDKey;

extern NSString * const TGMessagePollOptionTextKey;
extern NSString * const TGMessagePollOptionVoteCountKey;
extern NSString * const TGMessagePollOptionChosenKey;
extern NSString * const TGMessagePollOptionBeingChosenKey;

NSString *TGMessagePollTextFromFormattedObject(id object);
NSDictionary *TGMessagePollInfoFromContentObject(id contentObject);
NSString *TGMessagePollPreviewTextFromInfo(NSDictionary *pollInfo);
