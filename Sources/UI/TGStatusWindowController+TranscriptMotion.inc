- (void)rememberLiveArrivalFromSummary:(NSDictionary *)summary {
    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    NSNumber *messageID = [summary objectForKey:@"message_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)] ||
        [messageID longLongValue] <= 0 || ![chatID isEqual:self.selectedChatID]) { return; }
    if ([self.pendingArrivalMessageIDs count] >= 128) { [self.pendingArrivalMessageIDs removeAllObjects]; }
    [self.pendingArrivalMessageIDs addObject:messageID];
}

- (BOOL)messageItemSupportsDecorativeMotion:(TGMessageItem *)item {
    NSString *type = [item contentType];
    /* Inline playback/loader overlays have their own geometry; keep them stable. */
    return ![type isEqualToString:@"messageVideo"] && ![type isEqualToString:@"messageVideoNote"] &&
           ![type isEqualToString:@"messageAnimation"] && ![type isEqualToString:@"messageSticker"] &&
           ![type isEqualToString:@"messageAudio"] && ![type isEqualToString:@"messageVoiceNote"];
}

- (void)animatePendingLiveArrivals:(BOOL)nearNewest {
    if (nearNewest && TGInterfaceAnimationsEnabledForView(self.messageTableView)) {
        NSUInteger row = 0;
        for (TGMessageItem *item in self.messageItems) {
            if ([self.pendingArrivalMessageIDs containsObject:[item messageID]] &&
                [self messageItemSupportsDecorativeMotion:item]) {
                [self.transcriptMotionController beginArrivalForChatID:[item chatID] messageID:[item messageID]
                                                                  row:row outgoing:[item outgoing]];
            }
            row++;
        }
    }
    [self.pendingArrivalMessageIDs removeAllObjects];
}

- (BOOL)animateConfirmedRemovalWithID:(NSNumber *)messageID chatID:(NSNumber *)chatID {
    if (![chatID isEqual:self.selectedChatID] || !TGInterfaceAnimationsEnabledForView(self.messageTableView)) {
        return [self removeDisplayedMessageWithID:messageID chatID:chatID];
    }
    NSUInteger row = 0;
    for (TGMessageItem *item in self.messageItems) {
        if ([[item messageID] isEqual:messageID] && [[item chatID] isEqual:chatID]) {
            if (![self messageItemSupportsDecorativeMotion:item]) {
                return [self removeDisplayedMessageWithID:messageID chatID:chatID];
            }
            NSUInteger generation = self.messageLoadingGeneration;
            TGTDLibClient *client = self.client;
            [self.transcriptMotionController beginRemovalForChatID:chatID messageID:messageID row:row
                                                        outgoing:[item outgoing] completion:^{
                if (self.client == client && [self.selectedChatID isEqual:chatID] &&
                    self.messageLoadingGeneration == generation) {
                    [self removeDisplayedMessageWithID:messageID chatID:chatID];
                    self.pendingLiveMessageRefresh = YES;
                    [self performSelector:@selector(handlePendingLiveRefreshesIfPossible) withObject:nil afterDelay:0.0];
                }
            }];
            return YES;
        }
        row++;
    }
    return NO;
}
