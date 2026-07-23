#import <Foundation/Foundation.h>
#include <stdio.h>

#import "../Sources/Core/TGChatItem.h"
#import "../Sources/Core/TGDemoContent.h"
#import "../Sources/Core/TGDemoSession.h"
#import "../Sources/Core/TGMessageItem.h"

static BOOL TGCheck(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Demo content probe failed: %s\n", [message UTF8String]);
        return NO;
    }
    return YES;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL passed = YES;
    NSArray *chats = [TGDemoContent chatItems];
    passed = TGCheck([chats count] >= 5, @"expected a useful demo chat list") && passed;
    NSArray *folders = [TGDemoContent chatFolderItems];
    passed = TGCheck([folders count] == 4, @"expected four useful demo chat folders") && passed;

    TGChatItem *firstChat = ([chats count] > 0) ? [chats objectAtIndex:0] : nil;
    passed = TGCheck([firstChat isKindOfClass:[TGChatItem class]], @"first row should be a chat item") && passed;
    passed = TGCheck([[firstChat title] isEqualToString:@"Mavericks Club"], @"primary demo chat title changed") && passed;

    NSArray *messages = [TGDemoContent messageItemsForChatID:[firstChat chatID]];
    passed = TGCheck([messages count] >= 6, @"primary chat should fill the conversation pane") && passed;
    NSDictionary *profile = [TGDemoContent profileSummary];
    passed = TGCheck([[profile objectForKey:@"display_name"] length] > 0, @"demo profile needs a display name") && passed;
    passed = TGCheck([[profile objectForKey:@"username"] length] > 0, @"demo profile needs a username") && passed;

    NSUInteger outgoingCount = 0;
    NSUInteger incomingCount = 0;
    NSUInteger index = 0;
    for (index = 0; index < [messages count]; index++) {
        TGMessageItem *item = [messages objectAtIndex:index];
        if ([item outgoing]) {
            outgoingCount++;
        } else {
            incomingCount++;
        }
        passed = TGCheck([[item preview] length] > 0, @"every demo message needs visible text") && passed;
    }

    passed = TGCheck(outgoingCount > 0 && incomingCount > 0, @"conversation should show both sides") && passed;

    TGDemoSession *session = [[[TGDemoSession alloc] init] autorelease];
    NSUInteger originalCount = [[session messagesForChatID:[firstChat chatID]] count];
    NSArray *yearMatches = [session searchMessagesForChatID:[firstChat chatID] query:@"2011"];
    passed = TGCheck([yearMatches count] == 2, @"demo search should find both messages containing 2011") && passed;
    NSArray *caseInsensitiveMatches = [session searchMessagesForChatID:[firstChat chatID] query:@"MAVERICKS"];
    passed = TGCheck([caseInsensitiveMatches count] > 0, @"demo search should be case-insensitive") && passed;
    passed = TGCheck([[session searchMessagesForChatID:[firstChat chatID] query:@"not-in-this-demo"] count] == 0,
                     @"demo search should return an empty result for missing text") && passed;
    TGMessageItem *localText = [session appendTextMessage:@"Local demo reply"
                                                  chatID:[firstChat chatID]
                                            replyMessage:[messages objectAtIndex:0]];
    passed = TGCheck(localText != nil && [localText outgoing], @"demo text send should create an outgoing message") && passed;
    passed = TGCheck([[localText replyToMessageID] respondsToSelector:@selector(longLongValue)], @"demo reply should retain local reply context") && passed;
    TGMessageItem *localFile = [session appendDocumentMessageWithFileName:@"Screenshot.png"
                                                                 fileSize:2048
                                                                typeLabel:@"Image"
                                                                  caption:@"Demo attachment"
                                                                   chatID:[firstChat chatID]];
    passed = TGCheck([[localFile contentType] isEqualToString:@"messageDocument"], @"demo file send should create a document message") && passed;
    TGMessageItem *localSticker = [session appendStickerMessageWithLocalPath:@"/tmp/demo-sticker.png"
                                                                       emoji:@":-)"
                                                                       width:[NSNumber numberWithInteger:512]
                                                                      height:[NSNumber numberWithInteger:512]
                                                                      chatID:[firstChat chatID]];
    passed = TGCheck([[localSticker contentType] isEqualToString:@"messageSticker"], @"demo sticker send should create a sticker message") && passed;
    passed = TGCheck([[localSticker mediaLocalPath] isEqualToString:@"/tmp/demo-sticker.png"], @"demo sticker should keep its local image") && passed;
    TGMessageItem *localVoice = [session appendVoiceMessageWithLocalPath:@"/tmp/demo-voice.m4a"
                                                                duration:[NSNumber numberWithInteger:3]
                                                                  chatID:[firstChat chatID]];
    passed = TGCheck([[localVoice contentType] isEqualToString:@"messageVoiceNote"], @"demo voice send should create a voice message") && passed;
    passed = TGCheck([[localVoice mediaDuration] integerValue] == 3, @"demo voice should keep its duration") && passed;
    passed = TGCheck([[session messagesForChatID:[firstChat chatID]] count] == originalCount + 4, @"demo sends should persist in the local session") && passed;
    NSUInteger deletedMessageCount = [session deleteMessageIDs:[NSArray arrayWithObject:[localText messageID]]
                                                        chatID:[firstChat chatID]];
    passed = TGCheck(deletedMessageCount == 1, @"demo message deletion should remove one matching message") && passed;
    passed = TGCheck([[session messagesForChatID:[firstChat chatID]] count] == originalCount + 3,
                     @"deleted demo message should no longer be in the local session") && passed;

    NSArray *unreadChats = [session chatItemsForFolderID:[NSNumber numberWithInteger:101]];
    NSArray *personalChats = [session chatItemsForFolderID:[NSNumber numberWithInteger:102]];
    NSArray *groupChats = [session chatItemsForFolderID:[NSNumber numberWithInteger:103]];
    NSArray *mutedChats = [session chatItemsForFolderID:[NSNumber numberWithInteger:104]];
    passed = TGCheck([unreadChats count] == 3, @"unread folder should contain chats with unread messages") && passed;
    passed = TGCheck([personalChats count] == 3, @"personal folder should contain private chats") && passed;
    passed = TGCheck([groupChats count] == 3, @"groups folder should contain group chats") && passed;
    passed = TGCheck([mutedChats count] == 1, @"muted folder should contain muted chats") && passed;

    TGDemoSession *chatDeletionSession = [[[TGDemoSession alloc] init] autorelease];
    TGChatItem *deletedChat = [[chatDeletionSession chatItems] objectAtIndex:1];
    NSNumber *deletedChatID = [[deletedChat chatID] retain];
    NSUInteger originalChatCount = [[chatDeletionSession chatItems] count];
    passed = TGCheck([chatDeletionSession deleteChatID:deletedChatID], @"demo chat deletion should remove an existing chat") && passed;
    passed = TGCheck([[chatDeletionSession chatItems] count] == originalChatCount - 1,
                     @"deleted demo chat should no longer be in the chat list") && passed;
    passed = TGCheck([[chatDeletionSession messagesForChatID:deletedChatID] count] == 0,
                     @"deleting a demo chat should also remove its local messages") && passed;
    [deletedChatID release];

    if (passed) {
        printf("Demo content probe passed: %lu chats and %lu primary messages.\n",
               (unsigned long)[chats count],
               (unsigned long)[messages count]);
    }
    [pool drain];
    return passed ? 0 : 1;
}
