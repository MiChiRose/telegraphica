#import "TGDemoSession.h"

#import "TGChatItem.h"
#import "TGDemoContent.h"
#import "TGMessageItem.h"

@interface TGDemoSession ()
@property (nonatomic, retain, readwrite) NSArray *chatItems;
@property (nonatomic, retain, readwrite) NSDictionary *profileSummary;
@property (nonatomic, retain) NSMutableDictionary *messagesByChatID;
@property (nonatomic, assign) long long nextMessageID;
@end

@implementation TGDemoSession

@synthesize chatItems = _chatItems;
@synthesize profileSummary = _profileSummary;
@synthesize messagesByChatID = _messagesByChatID;
@synthesize nextMessageID = _nextMessageID;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.chatItems = [TGDemoContent chatItems];
        self.profileSummary = [TGDemoContent profileSummary];
        self.messagesByChatID = [NSMutableDictionary dictionary];
        self.nextMessageID = 900000LL;

        NSUInteger index = 0;
        for (index = 0; index < [self.chatItems count]; index++) {
            id candidate = [self.chatItems objectAtIndex:index];
            TGChatItem *chat = [candidate isKindOfClass:[TGChatItem class]] ? (TGChatItem *)candidate : nil;
            NSNumber *chatID = [chat chatID];
            if (![chatID respondsToSelector:@selector(longLongValue)]) {
                continue;
            }
            NSString *key = [self keyForChatID:chatID];
            NSArray *messages = [TGDemoContent messageItemsForChatID:chatID];
            [self.messagesByChatID setObject:[NSMutableArray arrayWithArray:messages] forKey:key];
        }
    }
    return self;
}

- (NSString *)keyForChatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", [chatID longLongValue]];
}

- (NSMutableArray *)mutableMessagesForChatID:(NSNumber *)chatID createIfNeeded:(BOOL)createIfNeeded {
    NSString *key = [self keyForChatID:chatID];
    if ([key length] == 0) {
        return nil;
    }
    NSMutableArray *messages = [self.messagesByChatID objectForKey:key];
    if (!messages && createIfNeeded) {
        messages = [NSMutableArray array];
        [self.messagesByChatID setObject:messages forKey:key];
    }
    return messages;
}

- (NSArray *)messagesForChatID:(NSNumber *)chatID {
    NSMutableArray *messages = [self mutableMessagesForChatID:chatID createIfNeeded:NO];
    return messages ? [NSArray arrayWithArray:messages] : [NSArray array];
}

- (NSArray *)chatItemsForFolderID:(NSNumber *)folderID {
    if (![folderID respondsToSelector:@selector(integerValue)]) {
        return [NSArray arrayWithArray:self.chatItems];
    }

    NSInteger folderValue = [folderID integerValue];
    NSMutableArray *matches = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        NSString *typeSummary = [[item typeSummary] lowercaseString];
        BOOL include = NO;
        if (folderValue == 101) {
            include = ([[item unreadCount] respondsToSelector:@selector(integerValue)] &&
                       [[item unreadCount] integerValue] > 0);
        } else if (folderValue == 102) {
            include = ([typeSummary rangeOfString:@"private"].location != NSNotFound);
        } else if (folderValue == 103) {
            include = ([typeSummary rangeOfString:@"group"].location != NSNotFound);
        } else if (folderValue == 104) {
            include = [item notificationsMuted];
        }
        if (include) {
            [matches addObject:item];
        }
    }
    return matches;
}

- (NSArray *)searchMessagesForChatID:(NSNumber *)chatID query:(NSString *)query {
    NSString *trimmedQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedQuery length] == 0) {
        return [NSArray array];
    }
    NSArray *messages = [self messagesForChatID:chatID];
    NSMutableArray *matches = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [messages count]; index++) {
        id candidate = [messages objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        NSArray *searchableValues = [NSArray arrayWithObjects:
                                     ([item preview] ? [item preview] : @""),
                                     ([item senderDisplayName] ? [item senderDisplayName] : @""),
                                     ([item downloadFileName] ? [item downloadFileName] : @""),
                                     nil];
        NSUInteger valueIndex = 0;
        BOOL matched = NO;
        for (valueIndex = 0; valueIndex < [searchableValues count]; valueIndex++) {
            NSString *value = [searchableValues objectAtIndex:valueIndex];
            if ([value rangeOfString:trimmedQuery options:NSCaseInsensitiveSearch].location != NSNotFound) {
                matched = YES;
                break;
            }
        }
        if (matched) {
            [matches addObject:item];
        }
    }
    return matches;
}

- (NSUInteger)deleteMessageIDs:(NSArray *)messageIDs chatID:(NSNumber *)chatID {
    NSMutableArray *messages = [self mutableMessagesForChatID:chatID createIfNeeded:NO];
    if (!messages || [messageIDs count] == 0) {
        return 0;
    }

    NSMutableSet *identifiers = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [messageIDs count]; index++) {
        id candidate = [messageIDs objectAtIndex:index];
        if ([candidate respondsToSelector:@selector(longLongValue)]) {
            [identifiers addObject:[NSString stringWithFormat:@"%lld", [candidate longLongValue]]];
        }
    }
    if ([identifiers count] == 0) {
        return 0;
    }

    NSUInteger originalCount = [messages count];
    NSIndexSet *indexes = [messages indexesOfObjectsPassingTest:^BOOL(id candidate, NSUInteger candidateIndex, BOOL *stop) {
        (void)candidateIndex;
        (void)stop;
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            return NO;
        }
        NSNumber *messageID = [(TGMessageItem *)candidate messageID];
        NSString *identifier = [messageID respondsToSelector:@selector(longLongValue)]
            ? [NSString stringWithFormat:@"%lld", [messageID longLongValue]]
            : nil;
        return (identifier && [identifiers containsObject:identifier]);
    }];
    [messages removeObjectsAtIndexes:indexes];
    return originalCount - [messages count];
}

- (BOOL)deleteChatID:(NSNumber *)chatID {
    NSString *key = [self keyForChatID:chatID];
    if ([key length] == 0) {
        return NO;
    }

    NSMutableArray *remainingChats = [NSMutableArray array];
    BOOL removed = NO;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        TGChatItem *item = [candidate isKindOfClass:[TGChatItem class]] ? (TGChatItem *)candidate : nil;
        if ([[item chatID] respondsToSelector:@selector(longLongValue)] &&
            [[item chatID] longLongValue] == [chatID longLongValue]) {
            removed = YES;
            continue;
        }
        [remainingChats addObject:candidate];
    }
    if (!removed) {
        return NO;
    }
    self.chatItems = [NSArray arrayWithArray:remainingChats];
    [self.messagesByChatID removeObjectForKey:key];
    return YES;
}

- (TGMessageItem *)baseOutgoingMessageForChatID:(NSNumber *)chatID preview:(NSString *)preview {
    self.nextMessageID += 1LL;
    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:chatID
                                                       messageID:[NSNumber numberWithLongLong:self.nextMessageID]
                                                            date:[NSNumber numberWithInteger:(NSInteger)[[NSDate date] timeIntervalSince1970]]
                                                        outgoing:YES
                                                         preview:([preview length] > 0 ? preview : @"Demo message")] autorelease];
    item.senderID = [self.profileSummary objectForKey:@"user_id"];
    item.senderDisplayName = @"You";
    item.outgoingRead = YES;
    item.capabilitiesKnown = YES;
    item.canBeReplied = YES;
    item.canBeEdited = YES;
    item.canBeDeletedOnlyForSelf = YES;
    item.canBeDeletedForAllUsers = YES;
    return item;
}

- (TGMessageItem *)appendTextMessage:(NSString *)text
                              chatID:(NSNumber *)chatID
                        replyMessage:(TGMessageItem *)replyMessage {
    if ([text length] == 0 || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    TGMessageItem *item = [self baseOutgoingMessageForChatID:chatID preview:text];
    item.contentType = @"messageText";
    item.editableText = text;
    if ([replyMessage isKindOfClass:[TGMessageItem class]]) {
        item.replyToMessageID = [replyMessage messageID];
        item.replySenderDisplayName = [[replyMessage senderDisplayName] length] > 0 ? [replyMessage senderDisplayName] : @"Message";
        item.replyPreview = [[replyMessage preview] length] > 0 ? [replyMessage preview] : @"Original message";
    }
    [[self mutableMessagesForChatID:chatID createIfNeeded:YES] addObject:item];
    return item;
}

- (TGMessageItem *)appendDocumentMessageWithFileName:(NSString *)fileName
                                            fileSize:(unsigned long long)fileSize
                                           typeLabel:(NSString *)typeLabel
                                             caption:(NSString *)caption
                                              chatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    NSString *safeName = [fileName length] > 0 ? fileName : @"Demo attachment";
    NSString *preview = [caption length] > 0 ? caption : [NSString stringWithFormat:@"%@: %@", [typeLabel length] > 0 ? typeLabel : @"File", safeName];
    TGMessageItem *item = [self baseOutgoingMessageForChatID:chatID preview:preview];
    item.contentType = @"messageDocument";
    item.downloadFileName = safeName;
    item.downloadFileSize = [NSNumber numberWithUnsignedLongLong:fileSize];
    item.mediaMimeType = @"application/octet-stream";
    item.editableText = nil;
    [[self mutableMessagesForChatID:chatID createIfNeeded:YES] addObject:item];
    return item;
}

- (TGMessageItem *)appendStickerMessageWithLocalPath:(NSString *)localPath
                                               emoji:(NSString *)emoji
                                               width:(NSNumber *)width
                                              height:(NSNumber *)height
                                              chatID:(NSNumber *)chatID {
    if ([localPath length] == 0 || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    NSString *preview = [emoji length] > 0 ? [NSString stringWithFormat:@"Sticker %@", emoji] : @"Sticker";
    TGMessageItem *item = [self baseOutgoingMessageForChatID:chatID preview:preview];
    item.contentType = @"messageSticker";
    item.mediaLocalPath = localPath;
    item.mediaWidth = [width respondsToSelector:@selector(integerValue)] ? width : [NSNumber numberWithInteger:512];
    item.mediaHeight = [height respondsToSelector:@selector(integerValue)] ? height : [NSNumber numberWithInteger:512];
    item.mediaMimeType = @"image/png";
    item.editableText = nil;
    [[self mutableMessagesForChatID:chatID createIfNeeded:YES] addObject:item];
    return item;
}

- (TGMessageItem *)appendVoiceMessageWithLocalPath:(NSString *)localPath
                                          duration:(NSNumber *)duration
                                            chatID:(NSNumber *)chatID {
    if ([localPath length] == 0 || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    TGMessageItem *item = [self baseOutgoingMessageForChatID:chatID preview:@"Voice message"];
    item.contentType = @"messageVoiceNote";
    item.mediaLocalPath = localPath;
    item.mediaDuration = [duration respondsToSelector:@selector(integerValue)] ? duration : [NSNumber numberWithInteger:1];
    item.mediaMimeType = @"audio/mp4";
    item.downloadFileName = [localPath lastPathComponent];
    item.editableText = nil;
    [[self mutableMessagesForChatID:chatID createIfNeeded:YES] addObject:item];
    return item;
}

- (void)dealloc {
    [_chatItems release];
    [_profileSummary release];
    [_messagesByChatID release];
    [super dealloc];
}

@end
