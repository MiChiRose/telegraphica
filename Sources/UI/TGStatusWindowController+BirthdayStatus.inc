static BOOL TGBirthdateIsToday(NSDictionary *birthdate) {
    if (![birthdate isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSInteger day = [[birthdate objectForKey:@"day"] integerValue];
    NSInteger month = [[birthdate objectForKey:@"month"] integerValue];
    NSDateComponents *today = [[NSCalendar currentCalendar]
                               components:(NSDayCalendarUnit | NSMonthCalendarUnit)
                               fromDate:[NSDate date]];
    return (day == [today day] && month == [today month]);
}

- (void)refreshSelectedChatBirthdayStatus {
    self.selectedChatBirthdayGeneration++;
    NSUInteger generation = self.selectedChatBirthdayGeneration;
    NSNumber *chatID = [[self.selectedChatID retain] autorelease];
    self.selectedChatBirthdayText = nil;
    self.selectedChatSafetyNoticeText = nil;
    [self refreshSelectedChatHeaderDisplay];
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![self.selectedChatTypeSummary isEqualToString:@"Private"] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *chat = [client chatSummaryForChatID:chatID
                                           downloadAvatar:NO
                                                   timeout:3.0
                                                     error:NULL];
        NSNumber *userID = [chat objectForKey:@"user_id"];
        NSDictionary *profile = nil;
        if ([userID respondsToSelector:@selector(longLongValue)] && [userID longLongValue] != 0LL) {
            profile = [client userProfileSummaryForUserID:userID timeout:3.0 error:NULL];
        }
        BOOL isBirthdayToday = TGBirthdateIsToday([profile objectForKey:@"birthdate"]);
        BOOL isBot = [[profile objectForKey:@"is_bot"] boolValue];
        BOOL isContact = [[profile objectForKey:@"is_contact"] boolValue];
        BOOL isMutualContact = [[profile objectForKey:@"is_mutual_contact"] boolValue];
        BOOL isScam = [[profile objectForKey:@"is_scam"] boolValue];
        BOOL isFake = [[profile objectForKey:@"is_fake"] boolValue];
        NSString *safetyNotice = nil;
        if (isScam || isFake) {
            safetyNotice = TGLoc(@"chat.safety.flagged.detail");
        } else if (!isBot && !isContact && !isMutualContact) {
            safetyNotice = TGLoc(@"chat.safety.unknown.detail");
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.selectedChatBirthdayGeneration &&
                [chatID longLongValue] == [self.selectedChatID longLongValue]) {
                self.selectedChatBirthdayText = isBirthdayToday ? TGLoc(@"chat.birthdayToday") : nil;
                self.selectedChatSafetyNoticeText = safetyNotice;
                [self.chatSafetyNoticeTitleField setStringValue:
                 ((isScam || isFake) ? TGLoc(@"chat.safety.flagged.title") : TGLoc(@"chat.safety.unknown.title"))];
                [self.chatSafetyNoticeDetailField setStringValue:(safetyNotice ? safetyNotice : @"")];
                [self refreshSelectedChatHeaderDisplay];
                [self updateVisibleSection];
                [self layoutContentView];
            }
            [client release];
        });
    });
}
