#import "TGAccessibilitySupport.h"
#import "TGLocalization.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"

static void TGAccessibilityAppendPart(NSMutableArray *parts, NSString *part) {
    if ([part isKindOfClass:[NSString class]] && [part length] > 0) {
        [parts addObject:part];
    }
}

static void TGAccessibilitySetOverride(id element, id value, NSString *attribute) {
    if (!element || !value || [attribute length] == 0 ||
        ![element respondsToSelector:@selector(accessibilitySetOverrideValue:forAttribute:)]) {
        return;
    }
    [element accessibilitySetOverrideValue:value forAttribute:attribute];
}

void TGAccessibilityConfigureButton(NSButton *button, NSString *label, NSString *help) {
    if (!button) {
        return;
    }
    NSString *safeLabel = [label isKindOfClass:[NSString class]] ? label : @"";
    NSString *safeHelp = [help isKindOfClass:[NSString class]] ? help : @"";
    [button setFocusRingType:NSFocusRingTypeDefault];
    TGAccessibilitySetOverride(button, NSAccessibilityButtonRole, NSAccessibilityRoleAttribute);
    if ([safeLabel length] > 0) {
        TGAccessibilitySetOverride(button, safeLabel, NSAccessibilityTitleAttribute);
    }
    if ([safeHelp length] > 0) {
        TGAccessibilitySetOverride(button, safeHelp, NSAccessibilityHelpAttribute);
    }
    TGAccessibilityUpdateButtonState(button);
}

void TGAccessibilityUpdateButtonState(NSButton *button) {
    if (!button) {
        return;
    }
    TGAccessibilitySetOverride(button,
                               [NSNumber numberWithBool:[button isEnabled]],
                               NSAccessibilityEnabledAttribute);
    TGAccessibilitySetOverride(button,
                               [NSNumber numberWithBool:([button state] == NSOnState)],
                               NSAccessibilityValueAttribute);
}

void TGAccessibilityConfigureList(NSTableView *tableView, NSString *label) {
    if (!tableView) {
        return;
    }
    TGAccessibilitySetOverride(tableView, NSAccessibilityListRole, NSAccessibilityRoleAttribute);
    if ([label isKindOfClass:[NSString class]] && [label length] > 0) {
        TGAccessibilitySetOverride(tableView, label, NSAccessibilityTitleAttribute);
    }
}

void TGAccessibilityConfigureContent(id element, NSString *description) {
    if (!element || ![description isKindOfClass:[NSString class]] || [description length] == 0) {
        return;
    }
    TGAccessibilitySetOverride(element, NSAccessibilityStaticTextRole, NSAccessibilityRoleAttribute);
    TGAccessibilitySetOverride(element, description, NSAccessibilityTitleAttribute);
    TGAccessibilitySetOverride(element, description, NSAccessibilityValueAttribute);
}

NSString *TGAccessibilityDescriptionForChatItem(TGChatItem *item) {
    if (![item isKindOfClass:[TGChatItem class]]) {
        return @"";
    }
    NSMutableArray *parts = [NSMutableArray array];
    NSString *title = [item isSavedMessages] ? TGLoc(@"savedMessages") : [item title];
    TGAccessibilityAppendPart(parts, title);
    TGAccessibilityAppendPart(parts, [item typeSummary]);
    NSInteger unreadCount = [[item unreadCount] respondsToSelector:@selector(integerValue)]
        ? [[item unreadCount] integerValue] : 0;
    if (unreadCount > 0) {
        TGAccessibilityAppendPart(parts,
                                  [NSString stringWithFormat:@"%@: %ld",
                                   TGLoc(@"message.unreadSeparator"), (long)unreadCount]);
    } else if ([item isMarkedAsUnread]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"message.unreadSeparator"));
    }
    if ([item notificationsMuted]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"chat.notifications.mutedBadge"));
    }
    if ([item isPinned]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"pinned.title"));
    }
    if ([item isCommunity]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"chat.community.badge"));
    }
    return [parts componentsJoinedByString:@", "];
}

static NSString *TGAccessibilityMediaDescriptionForMessageItem(TGMessageItem *item) {
    if ([item isStickerMessage]) {
        return TGLoc(@"media.sticker");
    }
    if ([item isVoiceNoteMessage]) {
        return TGLoc(@"media.voice");
    }
    if ([item isVideoNoteMessage]) {
        return TGLoc(@"media.videoNote");
    }
    if ([item isPhotoMessage]) {
        return TGLoc(@"storage.type.photos");
    }
    if ([[item contentType] isEqualToString:@"messageVideo"] ||
        [[item contentType] isEqualToString:@"messageAnimation"]) {
        return TGLoc(@"media.video");
    }
    if ([item isDocumentMessage]) {
        return TGLoc(@"media.document");
    }
    if ([item isPollMessage]) {
        return TGLoc(@"poll.create.title");
    }
    if ([item isCallMessage]) {
        return [item outgoing] ? TGLoc(@"calls.outgoingCall") : TGLoc(@"calls.incoming");
    }
    return @"";
}

NSString *TGAccessibilityDescriptionForMessageItem(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return @"";
    }
    NSMutableArray *parts = [NSMutableArray array];
    TGAccessibilityAppendPart(parts, [item outgoing] ? TGLoc(@"calls.outgoing") : [item senderDisplayName]);
    NSString *mediaDescription = TGAccessibilityMediaDescriptionForMessageItem(item);
    NSString *preview = [item preview];
    if ([mediaDescription length] > 0) {
        TGAccessibilityAppendPart(parts, mediaDescription);
    }
    if ([preview length] > 0 && ![preview isEqualToString:@"[Message]"]) {
        TGAccessibilityAppendPart(parts, preview);
    }
    if ([item sending]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"sending"));
    } else if ([item failedToSend]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"message.sendFailed"));
    } else if ([item outgoing]) {
        TGAccessibilityAppendPart(parts,
                                  [item outgoingRead] ? TGLoc(@"chat.markRead") : TGLoc(@"message.retry.sent"));
    }
    if ([item isPinned]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"pinned.title"));
    }
    if ([[item reactionSummary] length] > 0) {
        TGAccessibilityAppendPart(parts,
                                  [NSString stringWithFormat:@"%@: %@",
                                   TGLoc(@"message.reactions.usersTitle"), [item reactionSummary]]);
    }
    if ([item showsUnreadSeparator]) {
        TGAccessibilityAppendPart(parts, TGLoc(@"message.unreadSeparator"));
    }
    return [parts componentsJoinedByString:@", "];
}
