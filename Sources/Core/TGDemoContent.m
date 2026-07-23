#import "TGDemoContent.h"

#import "TGChatItem.h"
#import "TGMessageItem.h"

static NSTimeInterval TGDemoTimestamp(NSInteger minutesBeforeNow) {
    return [[NSDate date] timeIntervalSince1970] - ((NSTimeInterval)minutesBeforeNow * 60.0);
}

static TGChatItem *TGDemoChat(long long chatID,
                              NSString *title,
                              NSString *typeSummary,
                              NSInteger unreadCount,
                              BOOL pinned,
                              BOOL muted) {
    TGChatItem *item = [[[TGChatItem alloc] initWithChatID:[NSNumber numberWithLongLong:chatID]
                                                    title:title
                                              typeSummary:typeSummary
                                              unreadCount:[NSNumber numberWithInteger:unreadCount]] autorelease];
    item.pinned = pinned;
    item.notificationsMuted = muted;
    item.serverNotificationsMuted = muted;
    item.lastReadOutboxMessageID = [NSNumber numberWithLongLong:9000];
    return item;
}

static TGMessageItem *TGDemoMessage(long long chatID,
                                    long long messageID,
                                    NSInteger minutesBeforeNow,
                                    BOOL outgoing,
                                    NSString *senderName,
                                    NSString *text) {
    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithLongLong:chatID]
                                                      messageID:[NSNumber numberWithLongLong:messageID]
                                                           date:[NSNumber numberWithDouble:TGDemoTimestamp(minutesBeforeNow)]
                                                       outgoing:outgoing
                                                        preview:text] autorelease];
    item.contentType = @"messageText";
    item.senderDisplayName = senderName;
    item.senderID = [NSNumber numberWithLongLong:(outgoing ? 1 : (100 + messageID))];
    item.outgoingRead = outgoing;
    item.capabilitiesKnown = YES;
    item.canBeReplied = YES;
    item.canBeEdited = outgoing;
    item.canBeDeletedOnlyForSelf = YES;
    item.canBeDeletedForAllUsers = outgoing;
    item.editableText = outgoing ? text : nil;
    return item;
}

static TGMessageItem *TGDemoPhotoMessage(long long chatID,
                                         long long messageID,
                                         NSInteger minutesBeforeNow,
                                         BOOL outgoing,
                                         NSString *senderName,
                                         NSString *caption) {
    TGMessageItem *item = TGDemoMessage(chatID,
                                        messageID,
                                        minutesBeforeNow,
                                        outgoing,
                                        senderName,
                                        caption);
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"demo-lake-macbook"
                                                          ofType:@"png"];
    if ([imagePath length] > 0) {
        item.contentType = @"messagePhoto";
        item.mediaLocalPath = imagePath;
        item.mediaWidth = [NSNumber numberWithInteger:600];
        item.mediaHeight = [NSNumber numberWithInteger:450];
        item.mediaMimeType = @"image/png";
    }
    return item;
}

@implementation TGDemoContent

+ (BOOL)isEnabledFromEnvironment {
    id bundleFlag = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"TelegraphicaDemoMode"];
    if ([bundleFlag respondsToSelector:@selector(boolValue)] && [bundleFlag boolValue]) {
        return YES;
    }
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--demo-mode"]) {
        return YES;
    }
    NSString *value = [[[NSProcessInfo processInfo] environment] objectForKey:@"TELEGRAPHICA_DEMO_MODE"];
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *normalized = [value lowercaseString];
    return ([normalized isEqualToString:@"1"] ||
            [normalized isEqualToString:@"yes"] ||
            [normalized isEqualToString:@"true"]);
}

+ (NSDictionary *)profileSummary {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLongLong:4242424242LL], @"user_id",
            @"Alex Morgan", @"display_name",
            @"Alex", @"first_name",
            @"Morgan", @"last_name",
            @"alex_mavericks", @"username",
            @"+1 555 010 1984", @"phone_number",
            @"Keeping a 2011 MacBook useful, one native app at a time.", @"bio",
            nil];
}

+ (NSArray *)chatItems {
    TGChatItem *savedMessages = TGDemoChat(-1006, @"Saved Messages", @"Private", 0, NO, NO);
    savedMessages.savedMessages = YES;
    return [NSArray arrayWithObjects:
            TGDemoChat(-1001, @"Mavericks Club", @"Group", 0, YES, NO),
            TGDemoChat(-1002, @"Mia Chen", @"Private", 2, NO, NO),
            TGDemoChat(-1003, @"Legacy Mac Lab", @"Group", 4, NO, YES),
            TGDemoChat(-1004, @"Road Trip", @"Group", 0, NO, NO),
            TGDemoChat(-1005, @"Alex Morgan", @"Private", 1, NO, NO),
            savedMessages,
            nil];
}

+ (NSArray *)chatFolderItems {
    return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithInteger:101], @"id",
             @"Unread", @"title",
             nil],
            [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithInteger:102], @"id",
             @"Personal", @"title",
             nil],
            [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithInteger:103], @"id",
             @"Groups", @"title",
             nil],
            [NSDictionary dictionaryWithObjectsAndKeys:
             [NSNumber numberWithInteger:104], @"id",
             @"Muted", @"title",
             nil],
            nil];
}

+ (NSArray *)stickerItems {
    NSArray *descriptors = [NSArray arrayWithObjects:
                            [NSArray arrayWithObjects:@"happy-laptop", @"Laptop", @":-)", nil],
                            [NSArray arrayWithObjects:@"floppy-heart", @"Floppy disk", @"<3", nil],
                            [NSArray arrayWithObjects:@"coffee", @"Coffee", @":-)", nil],
                            [NSArray arrayWithObjects:@"chat-star", @"Chat star", @"*", nil],
                            [NSArray arrayWithObjects:@"compact-disc", @"Compact disc", @";-)", nil],
                            [NSArray arrayWithObjects:@"sleepy-moon", @"Sleepy moon", @"zZ", nil],
                            [NSArray arrayWithObjects:@"finder", @"Finder", @":-)", nil],
                            [NSArray arrayWithObjects:@"ipod-classic", @"iPod Classic", @":-)", nil],
                            [NSArray arrayWithObjects:@"macos-folder", @"Mac folder", @":-)", nil],
                            [NSArray arrayWithObjects:@"imac-g3", @"iMac G3", @":-)", nil],
                            [NSArray arrayWithObjects:@"imac-g4", @"iMac G4", @":-)", nil],
                            [NSArray arrayWithObjects:@"macintosh-classic", @"Macintosh Classic", @":-)", nil],
                            nil];
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count]; index++) {
        NSArray *descriptor = [descriptors objectAtIndex:index];
        NSString *resourceName = [NSString stringWithFormat:@"demo-sticker-%@", [descriptor objectAtIndex:0]];
        NSString *path = [[NSBundle mainBundle] pathForResource:resourceName
                                                        ofType:@"png"
                                                   inDirectory:@"Stickers"];
        if ([path length] == 0) {
            continue;
        }
        [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                          path, @"local_path",
                          @"messageSticker", @"content_type",
                          @"stickerFormatStatic", @"sticker_format",
                          [descriptor objectAtIndex:1], @"demo_name",
                          [descriptor objectAtIndex:2], @"emoji",
                          [NSNumber numberWithInteger:512], @"width",
                          [NSNumber numberWithInteger:512], @"height",
                          nil]];
    }
    return items;
}

+ (NSArray *)messageItemsForChatID:(NSNumber *)chatID {
    long long value = [chatID respondsToSelector:@selector(longLongValue)] ? [chatID longLongValue] : 0;
    NSMutableArray *items = [NSMutableArray array];

    if (value == -1001) {
        [items addObject:TGDemoMessage(value, 91, 48, NO, @"Mia Chen",
                                      @"I packed the 2011 MacBook for the weekend. It still wakes instantly and lasts long enough for notes, music, and Telegram.")];
        [items addObject:TGDemoMessage(value, 92, 44, YES, @"You",
                                      @"That is exactly why I wanted Telegraphica to stay lightweight. The machine should spend its time on your work, not on a browser tab.")];
        [items addObject:TGDemoMessage(value, 93, 40, NO, @"Alex Morgan",
                                      @"The classic interface also looks much more at home here than a modern web app.")];
        [items addObject:TGDemoMessage(value, 94, 36, YES, @"You",
                                      @"Agreed. Native AppKit, local rendering, and no background web engine.")];
        [items addObject:TGDemoPhotoMessage(value, 95, 32, NO, @"Mia Chen",
                                           @"And this was today's workspace. Old hardware still travels rather well.")];
        [items addObject:TGDemoMessage(value, 96, 29, YES, @"You",
                                      @"That view is doing most of the visual design work for us.")];
        [items addObject:TGDemoMessage(value, 97, 26, NO, @"Alex Morgan",
                                      @"Scrolling is smooth now too. I can keep a proper conversation open without the fans immediately taking over.")];
        [items addObject:TGDemoMessage(value, 98, 22, YES, @"You",
                                      @"Perfect. I am collecting a few realistic demo messages so people can explore the app without signing in.")];
        [items addObject:TGDemoMessage(value, 101, 18, NO, @"Mia Chen",
                                      @"Morning! Is Telegraphica really running on Mavericks?")];
        [items addObject:TGDemoMessage(value, 102, 15, YES, @"You",
                                      @"Yep. Native AppKit, with no browser tab in the background.")];
        [items addObject:TGDemoMessage(value, 103, 12, NO, @"Alex Morgan",
                                      @"How is the 2011 MacBook holding up?")];
        [items addObject:TGDemoMessage(value, 104, 9, YES, @"You",
                                      @"Quiet, responsive, and notifications work.")];
        [items addObject:TGDemoMessage(value, 105, 6, NO, @"Mia Chen",
                                      @"That is exactly what old Macs need.")];
        [items addObject:TGDemoMessage(value, 106, 2, YES, @"You",
                                      @"Great. One last screenshot for Reddit.")];
        return items;
    }

    if (value == -1002) {
        [items addObject:TGDemoMessage(value, 201, 42, NO, @"Mia Chen",
                                      @"The classic theme looks right at home on Mavericks.")];
        [items addObject:TGDemoMessage(value, 202, 39, YES, @"You",
                                      @"That was the goal: useful first, nostalgic second.")];
        [items addObject:TGDemoMessage(value, 203, 35, NO, @"Mia Chen",
                                      @"You managed both.")];
        return items;
    }

    if (value == -1003) {
        [items addObject:TGDemoMessage(value, 301, 64, NO, @"Ilya Novak",
                                      @"I tested the latest build on a 2011 MacBook Pro.")];
        [items addObject:TGDemoMessage(value, 302, 61, NO, @"Mia Chen",
                                      @"How is the scrolling now?")];
        [items addObject:TGDemoMessage(value, 303, 58, YES, @"You",
                                      @"Much smoother. I also reduced unnecessary background work.")];
        return items;
    }

    if (value == -1004) {
        [items addObject:TGDemoMessage(value, 401, 122, NO, @"Alex Morgan",
                                      @"I uploaded the lake photos from Sunday.")];
        [items addObject:TGDemoMessage(value, 402, 118, YES, @"You",
                                      @"Nice. I will check the album after the build finishes.")];
        return items;
    }

    if (value == -1005) {
        [items addObject:TGDemoMessage(value, 501, 21, NO, @"Alex Morgan",
                                      @"The README could use a real application screenshot.")];
        [items addObject:TGDemoMessage(value, 502, 19, YES, @"You",
                                      @"Working on it right now.")];
        return items;
    }

    [items addObject:TGDemoMessage(value, 601, 180, YES, @"You",
                                  @"Telegraphica screenshot checklist: chat list, open conversation, settings themes.")];
    return items;
}

@end
