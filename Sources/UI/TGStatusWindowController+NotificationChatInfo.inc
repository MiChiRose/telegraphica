/* Notification enrichment owns its captured client and pending request identity. */
- (void)requestNotificationChatInfoFetchForChatID:(NSNumber *)chatID cacheKey:(NSString *)cacheKey {
    if (!self.client) { return; }
    NSDictionary *cached = [self.notificationChatInfoByChatID objectForKey:cacheKey];
    if ([[cached objectForKey:@"fetch_pending"] boolValue] || [[cached objectForKey:@"fetch_complete"] boolValue]) {
        return;
    }
    id retryAfterObject = [cached objectForKey:@"fetch_retry_after"];
    if ([retryAfterObject respondsToSelector:@selector(doubleValue)] &&
        [retryAfterObject doubleValue] > [[NSDate date] timeIntervalSince1970]) {
        return;
    }
    NSMutableDictionary *pending = [NSMutableDictionary dictionary];
    if ([cached isKindOfClass:[NSDictionary class]]) {
        [pending addEntriesFromDictionary:cached];
    }
    [pending setObject:[NSNumber numberWithBool:YES] forKey:@"fetch_pending"];
    NSString *requestID = [[NSProcessInfo processInfo] globallyUniqueString];
    [pending setObject:requestID forKey:@"fetch_request_id"];
    [self.notificationChatInfoByChatID setObject:pending forKey:cacheKey];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             chatID, @"chatID",
                             cacheKey, @"cacheKey",
                             self.client, @"client",
                             requestID, @"requestID",
                             nil];
    [self performSelectorInBackground:@selector(fetchNotificationChatInfoInBackground:)
                           withObject:request];
}

- (void)fetchNotificationChatInfoInBackground:(NSDictionary *)request {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSNumber *chatID = [request objectForKey:@"chatID"];
    TGTDLibClient *client = [request objectForKey:@"client"];
    NSError *chatInfoError = nil;
    NSDictionary *fetchedInfo = nil;
    if ([client respondsToSelector:@selector(chatSummaryForChatID:downloadAvatar:timeout:error:)]) {
        fetchedInfo = [client chatSummaryForChatID:chatID
                                         downloadAvatar:YES
                                                timeout:1.2
                                                  error:&chatInfoError];
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:request];
    if ([fetchedInfo isKindOfClass:[NSDictionary class]] && [fetchedInfo count] > 0) {
        [result setObject:fetchedInfo forKey:@"info"];
    }
    NSString *errorMessage = [chatInfoError localizedDescription];
    if ([errorMessage length] > 0) {
        [result setObject:errorMessage forKey:@"error"];
    }
    [self performSelectorOnMainThread:@selector(applyFetchedNotificationChatInfo:)
                           withObject:result
                        waitUntilDone:NO];
    [pool drain];
}

- (void)applyFetchedNotificationChatInfo:(NSDictionary *)result {
    NSString *cacheKey = [result objectForKey:@"cacheKey"];
    if ([cacheKey length] == 0) {
        return;
    }
    NSDictionary *cached = [self.notificationChatInfoByChatID objectForKey:cacheKey];
    if ([result objectForKey:@"client"] != self.client ||
        ![[cached objectForKey:@"fetch_request_id"] isEqual:[result objectForKey:@"requestID"]]) { return; }
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    if ([cached isKindOfClass:[NSDictionary class]]) {
        [merged addEntriesFromDictionary:cached];
    }
    [merged removeObjectForKey:@"fetch_pending"];
    [merged removeObjectForKey:@"fetch_request_id"];
    NSDictionary *fetchedInfo = [result objectForKey:@"info"];
    if ([fetchedInfo isKindOfClass:[NSDictionary class]]) {
        [merged setObject:[NSNumber numberWithBool:YES] forKey:@"fetch_complete"];
        [merged removeObjectForKey:@"fetch_retry_after"];
        for (NSString *key in [NSArray arrayWithObjects:@"title", @"avatar_local_path", @"notifications_muted", nil]) {
            id value = [fetchedInfo objectForKey:key];
            if (value) {
                [merged setObject:value forKey:key];
            }
        }
    } else {
        [merged removeObjectForKey:@"fetch_complete"];
        [merged setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] + 5.0]
                   forKey:@"fetch_retry_after"];
    }
    [self.notificationChatInfoByChatID setObject:merged forKey:cacheKey];
    NSString *errorMessage = [result objectForKey:@"error"];
    if ([errorMessage length] > 0) {
        [self appendDetail:[NSString stringWithFormat:@"Notification chat info fallback: %@", errorMessage]];
    }
}

- (NSDictionary *)notificationChatInfoForChatID:(NSNumber *)chatID {
    NSString *cacheKey = [self notificationCacheKeyForChatID:chatID];
    if ([cacheKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    TGChatItem *item = [self chatItemForNotificationChatID:chatID];
    if ([item isKindOfClass:[TGChatItem class]]) {
        NSString *title = [item title];
        NSString *avatarPath = [item avatarLocalPath];
        if ([title length] > 0) {
            [info setObject:title forKey:@"title"];
        }
        if ([avatarPath length] > 0) {
            [info setObject:avatarPath forKey:@"avatar_local_path"];
        }
    }

    NSDictionary *cachedInfo = [self.notificationChatInfoByChatID objectForKey:cacheKey];
    if ([cachedInfo isKindOfClass:[NSDictionary class]]) {
        NSString *cachedTitle = [cachedInfo objectForKey:@"title"];
        NSString *cachedAvatarPath = [cachedInfo objectForKey:@"avatar_local_path"];
        id cachedMuted = [cachedInfo objectForKey:@"notifications_muted"];
        if ([[info objectForKey:@"title"] length] == 0 && [cachedTitle length] > 0) {
            [info setObject:cachedTitle forKey:@"title"];
        }
        if ([[info objectForKey:@"avatar_local_path"] length] == 0 && [cachedAvatarPath length] > 0) {
            [info setObject:cachedAvatarPath forKey:@"avatar_local_path"];
        }
        if (cachedMuted) {
            [info setObject:cachedMuted forKey:@"notifications_muted"];
        }
    }

    BOOL needsFetch = ([[info objectForKey:@"title"] length] == 0 || [[info objectForKey:@"avatar_local_path"] length] == 0);
    if (needsFetch && [self.client respondsToSelector:@selector(chatSummaryForChatID:downloadAvatar:timeout:error:)]) {
        [self requestNotificationChatInfoFetchForChatID:chatID cacheKey:cacheKey];
    }

    if ([info count] > 0) {
        NSMutableDictionary *storedInfo = [NSMutableDictionary dictionaryWithDictionary:info];
        NSDictionary *latestCachedInfo = [self.notificationChatInfoByChatID objectForKey:cacheKey];
        for (NSString *stateKey in [NSArray arrayWithObjects:@"fetch_pending", @"fetch_request_id", @"fetch_complete", @"fetch_retry_after", nil]) {
            id stateValue = [latestCachedInfo objectForKey:stateKey];
            if (stateValue) {
                [storedInfo setObject:stateValue forKey:stateKey];
            }
        }
        [self.notificationChatInfoByChatID setObject:storedInfo forKey:cacheKey];
        return info;
    }
    return nil;
}

