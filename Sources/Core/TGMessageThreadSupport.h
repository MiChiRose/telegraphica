#import <Foundation/Foundation.h>
@class TGMessageItem;

// Message properties moved out of message in newer TDLib versions. Reply info
// still identifies a discussion, including one that has no comments yet.
BOOL TGMessageCanGetThreadFromObject(NSDictionary *object);
NSNumber *TGMessageThreadReplyCountFromObject(NSDictionary *object);
void TGApplyMessageThreadMetadata(TGMessageItem *item, NSDictionary *message);
void TGMergeMessageThreadMetadata(TGMessageItem *albumItem, TGMessageItem *item);
NSNumber *TGMessageChatIDFromObject(NSDictionary *message, NSNumber *fallbackChatID);
NSDictionary *TGMessageThreadDestinationFromInfo(NSDictionary *threadInfo);
NSDictionary *TGMessageInteractionUpdateSummary(NSDictionary *update, NSDictionary *reactionInfo);
// Applies a matching update; returns YES only when visible metadata changed.
BOOL TGApplyMessageInteractionSummaryToItem(TGMessageItem *item, NSDictionary *summary);
// Search schema fallbacks must prove they returned the requested topic.
BOOL TGMessageThreadHistoryResponseIsScoped(NSDictionary *response, NSNumber *chatID, NSNumber *threadID, NSString *topicKind);
