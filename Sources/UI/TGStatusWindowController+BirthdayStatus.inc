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
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.selectedChatBirthdayGeneration &&
                [chatID longLongValue] == [self.selectedChatID longLongValue]) {
                self.selectedChatBirthdayText = isBirthdayToday ? TGLoc(@"chat.birthdayToday") : nil;
                [self refreshSelectedChatHeaderDisplay];
            }
            [client release];
        });
    });
}
