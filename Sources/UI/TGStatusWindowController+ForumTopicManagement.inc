static NSString * const TGForumTopicOperationCreate = @"create";
static NSString * const TGForumTopicOperationRename = @"rename";
static NSString * const TGForumTopicOperationClose = @"close";
static NSString * const TGForumTopicOperationReopen = @"reopen";
static NSString * const TGForumTopicOperationPin = @"pin";
static NSString * const TGForumTopicOperationUnpin = @"unpin";
static NSString * const TGForumTopicOperationDelete = @"delete";

- (NSString *)forumTopicNameFromPromptWithTitle:(NSString *)title
                                         detail:(NSString *)detail
                                   initialValue:(NSString *)initialValue
                                    actionTitle:(NSString *)actionTitle {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title ? title : @""];
    [alert setInformativeText:detail ? detail : @""];
    [alert addButtonWithTitle:actionTitle ? actionTitle : TGLoc(@"save")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSTextField *nameField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 0.0, 330.0, 24.0)] autorelease];
    [nameField setStringValue:initialValue ? initialValue : @""];
    [[nameField cell] setPlaceholderString:TGLoc(@"forum.topic.namePlaceholder")];
    [alert setAccessoryView:nameField];
    [[alert window] setInitialFirstResponder:nameField];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    return [[nameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (TGChatItem *)forumTopicItemFromSender:(id)sender {
    id representedObject = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    return ([representedObject isKindOfClass:[TGChatItem class]] && [representedObject isForumTopic]) ? representedObject : nil;
}

- (void)performForumTopicOperation:(NSString *)operation
                              item:(TGChatItem *)item
                              name:(NSString *)name {
    if (self.forumTopicMutationInFlight || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    NSNumber *chatID = nil;
    NSNumber *topicID = nil;
    if ([item isForumTopic]) {
        chatID = [item parentChatID];
        topicID = [item messageThreadID];
    } else {
        chatID = self.topicParentChatID;
    }
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        (![operation isEqualToString:TGForumTopicOperationCreate] &&
         ![topicID respondsToSelector:@selector(longLongValue)])) {
        [self.statusField setStringValue:TGLoc(@"forum.topic.invalid")];
        return;
    }

    self.forumTopicMutationInFlight = YES;
    [self.statusField setStringValue:TGLoc(@"forum.topic.saving")];
    [self appendDetail:[NSString stringWithFormat:@"Forum topic: %@ requested.", operation]];

    TGTDLibClient *client = [self.client retain];
    NSNumber *chatIDCopy = [[NSNumber numberWithLongLong:[chatID longLongValue]] retain];
    NSNumber *topicIDCopy = [topicID respondsToSelector:@selector(longLongValue)] ?
        [[NSNumber numberWithLongLong:[topicID longLongValue]] retain] : nil;
    NSString *operationCopy = [operation copy];
    NSString *nameCopy = [name copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *operationError = nil;
        BOOL success = NO;
        if ([operationCopy isEqualToString:TGForumTopicOperationCreate]) {
            success = [client createForumTopicInChatID:chatIDCopy name:nameCopy timeout:8.0 error:&operationError];
        } else if ([operationCopy isEqualToString:TGForumTopicOperationRename]) {
            success = [client renameForumTopicInChatID:chatIDCopy topicID:topicIDCopy name:nameCopy timeout:8.0 error:&operationError];
        } else if ([operationCopy isEqualToString:TGForumTopicOperationClose] ||
                   [operationCopy isEqualToString:TGForumTopicOperationReopen]) {
            success = [client setForumTopicInChatID:chatIDCopy
                                           topicID:topicIDCopy
                                            closed:[operationCopy isEqualToString:TGForumTopicOperationClose]
                                           timeout:8.0
                                             error:&operationError];
        } else if ([operationCopy isEqualToString:TGForumTopicOperationPin] ||
                   [operationCopy isEqualToString:TGForumTopicOperationUnpin]) {
            success = [client setForumTopicInChatID:chatIDCopy
                                           topicID:topicIDCopy
                                            pinned:[operationCopy isEqualToString:TGForumTopicOperationPin]
                                           timeout:8.0
                                             error:&operationError];
        } else if ([operationCopy isEqualToString:TGForumTopicOperationDelete]) {
            success = [client deleteForumTopicInChatID:chatIDCopy topicID:topicIDCopy timeout:8.0 error:&operationError];
        }
        NSString *errorMessage = [[operationError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.forumTopicMutationInFlight = NO;
            if (success) {
                [self.statusField setStringValue:TGLoc(@"forum.topic.saved")];
                [self appendDetail:[NSString stringWithFormat:@"Forum topic: %@ completed.", operationCopy]];
                [self reloadCurrentForumTopicListInteractive:NO];
            } else {
                [self.statusField setStringValue:TGLoc(@"forum.topic.failed")];
                if ([errorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"Forum topic: %@", errorMessage]];
                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert setMessageText:TGLoc(@"forum.topic.failed")];
                    [alert setInformativeText:errorMessage];
                    [alert addButtonWithTitle:TGLoc(@"close")];
                    [alert runModal];
                }
            }
            [client release];
            [chatIDCopy release];
            [topicIDCopy release];
            [operationCopy release];
            [nameCopy release];
            [errorMessage release];
        });
        [pool drain];
    });
}

- (void)createForumTopic:(id)sender {
    (void)sender;
    if (!self.showingForumTopicList) {
        [self openNewChatWindow:nil];
        return;
    }
    NSString *name = [self forumTopicNameFromPromptWithTitle:TGLoc(@"forum.topic.create")
                                                     detail:TGLoc(@"forum.topic.createHint")
                                               initialValue:@""
                                                actionTitle:TGLoc(@"forum.topic.createAction")];
    if ([name length] == 0) {
        return;
    }
    [self performForumTopicOperation:TGForumTopicOperationCreate item:nil name:name];
}

- (void)renameForumTopicFromMenu:(id)sender {
    TGChatItem *item = [self forumTopicItemFromSender:sender];
    if (!item) {
        return;
    }
    NSString *name = [self forumTopicNameFromPromptWithTitle:TGLoc(@"forum.topic.rename")
                                                     detail:TGLoc(@"forum.topic.renameHint")
                                               initialValue:[item title]
                                                actionTitle:TGLoc(@"save")];
    if ([name length] == 0 || [name isEqualToString:[item title]]) {
        return;
    }
    [self performForumTopicOperation:TGForumTopicOperationRename item:item name:name];
}

- (void)toggleForumTopicClosedFromMenu:(id)sender {
    TGChatItem *item = [self forumTopicItemFromSender:sender];
    if (!item) {
        return;
    }
    [self performForumTopicOperation:([item isForumTopicClosed] ? TGForumTopicOperationReopen : TGForumTopicOperationClose)
                                item:item
                                name:nil];
}

- (void)toggleForumTopicPinnedFromMenu:(id)sender {
    TGChatItem *item = [self forumTopicItemFromSender:sender];
    if (!item) {
        return;
    }
    [self performForumTopicOperation:([item isForumTopicPinned] ? TGForumTopicOperationUnpin : TGForumTopicOperationPin)
                                item:item
                                name:nil];
}

- (void)deleteForumTopicFromMenu:(id)sender {
    TGChatItem *item = [self forumTopicItemFromSender:sender];
    if (!item) {
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:[NSString stringWithFormat:TGLoc(@"forum.topic.deleteConfirmTitle"), [item title]]];
    [alert setInformativeText:TGLoc(@"forum.topic.deleteConfirm")];
    [alert addButtonWithTitle:TGLoc(@"forum.topic.delete")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    [self performForumTopicOperation:TGForumTopicOperationDelete item:item name:nil];
}

- (void)populateForumTopicContextMenu:(NSMenu *)menu forItem:(TGChatItem *)item {
    BOOL enabled = ([self.currentAuthState isEqualToString:@"ready"] && !self.forumTopicMutationInFlight);
    NSMenuItem *renameItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"forum.topic.rename")
                                                        action:@selector(renameForumTopicFromMenu:)
                                                 keyEquivalent:@""] autorelease];
    [renameItem setRepresentedObject:item];
    [renameItem setTarget:self];
    [renameItem setEnabled:enabled];
    [menu addItem:renameItem];

    NSMenuItem *closeItem = [[[NSMenuItem alloc] initWithTitle:TGLoc([item isForumTopicClosed] ? @"forum.topic.reopen" : @"forum.topic.close")
                                                       action:@selector(toggleForumTopicClosedFromMenu:)
                                                keyEquivalent:@""] autorelease];
    [closeItem setRepresentedObject:item];
    [closeItem setTarget:self];
    [closeItem setEnabled:enabled];
    [menu addItem:closeItem];

    NSMenuItem *pinItem = [[[NSMenuItem alloc] initWithTitle:TGLoc([item isForumTopicPinned] ? @"forum.topic.unpin" : @"forum.topic.pin")
                                                     action:@selector(toggleForumTopicPinnedFromMenu:)
                                              keyEquivalent:@""] autorelease];
    [pinItem setRepresentedObject:item];
    [pinItem setTarget:self];
    [pinItem setEnabled:enabled];
    [menu addItem:pinItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *deleteItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"forum.topic.delete")
                                                        action:@selector(deleteForumTopicFromMenu:)
                                                 keyEquivalent:@""] autorelease];
    [deleteItem setRepresentedObject:item];
    [deleteItem setTarget:self];
    [deleteItem setEnabled:enabled];
    [menu addItem:deleteItem];
}
