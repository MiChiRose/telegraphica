// Main-thread request identities outlive pagination, but never a changed chat,
// account or panel session. Keep the identity until a modal Save panel returns.
- (NSMutableDictionary *)newMediaCenterTransferRequestWithKind:(NSString *)kind {
    return [[NSMutableDictionary alloc] initWithObjectsAndKeys:
            kind, @"kind", self.client ? (id)self.client : (id)[NSNull null], @"client",
            self.selectedChatID ? (id)self.selectedChatID : (id)[NSNull null], @"chat",
            self.selectedMessageThreadID ? (id)self.selectedMessageThreadID : (id)[NSNull null], @"thread", nil];
}

- (BOOL)mediaCenterTransferRequestIsCurrent:(NSDictionary *)request fileID:(NSNumber *)fileID {
    id chat = self.selectedChatID ? (id)self.selectedChatID : (id)[NSNull null];
    id thread = self.selectedMessageThreadID ? (id)self.selectedMessageThreadID : (id)[NSNull null];
    return [self.mediaCenterSaveRequests objectForKey:fileID] == request &&
           [request objectForKey:@"client"] == self.client &&
           [self.currentAuthState isEqualToString:@"ready"] && self.mediaCenterVisible &&
           [[request objectForKey:@"chat"] isEqual:chat] &&
           [[request objectForKey:@"thread"] isEqual:thread];
}

- (void)finishMediaCenterTransferRequest:(NSDictionary *)request fileID:(NSNumber *)fileID {
    // Cancellation followed by an immediate retry must not lose the new marker.
    if ([self.mediaCenterSaveRequests objectForKey:fileID] == request) {
        [self.mediaCenterSaveRequests removeObjectForKey:fileID];
        [self.mediaCenterDownloadingFileIDs removeObject:fileID];
        [self rebuildMediaCenterRowsPreservingScroll:YES];
    }
}

- (void)downloadMediaCenterItem:(id)sender {
    if (!self.client || ![self.currentAuthState isEqualToString:@"ready"] || !self.mediaCenterVisible) { return; }
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSNumber *fileID = TGMediaCenterFileIDForItem(item);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.noFileID")];
        return;
    }
    if ([self.mediaCenterDownloadingFileIDs containsObject:fileID]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.alreadyDownloading")];
        return;
    }
    TGDownloadManager *manager = [TGDownloadManager sharedManager];
    [manager setClient:self.client];
    // The manager deduplicates without attaching a second completion. Avoid
    // creating an identity that would wait forever for that absent callback.
    for (NSDictionary *record in [manager itemsSnapshot]) {
        NSString *state = [record objectForKey:@"state"];
        if ([[record objectForKey:@"file_id"] longLongValue] == [fileID longLongValue] &&
            ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"] || [state isEqualToString:@"paused"])) {
            [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.alreadyDownloading")];
            return;
        }
    }
    NSNumber *fileIDCopy = [fileID retain];
    NSString *suggestedFileName = [TGMediaCenterTitleForItem(item) copy];
    NSMutableDictionary *request = [self newMediaCenterTransferRequestWithKind:@"manager"];
    [self.mediaCenterSaveRequests setObject:request forKey:fileIDCopy];
    [self.mediaCenterDownloadingFileIDs addObject:fileIDCopy];
    [self rebuildMediaCenterRowsPreservingScroll:YES];
    [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloading")];
    [manager enqueueFileID:fileIDCopy suggestedFileName:suggestedFileName
                                   fallbackLocalPath:TGMediaCenterLocalPathForItem(item)
                                          completion:^(NSString *savedPath, NSError *error, BOOL cancelled) {
        if ([self mediaCenterTransferRequestIsCurrent:request fileID:fileIDCopy]) {
            if ([savedPath length] > 0) {
                [self.mediaCenterSavedPathsByFileID setObject:savedPath forKey:fileIDCopy];
                [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:
                 TGLoc(@"media.center.downloadedTo"), TGDisplayPathForDownloadFolder(savedPath)]];
            } else if (cancelled) {
                [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloadCancelled")];
            } else {
                [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:
                 TGLoc(@"media.center.downloadFailed"), [[error localizedDescription] length] > 0 ?
                 [error localizedDescription] : TGLoc(@"downloads.unavailable")]];
            }
        }
        [self finishMediaCenterTransferRequest:request fileID:fileIDCopy];
        [request release];
        [suggestedFileName release];
        [fileIDCopy release];
    }];
}

- (void)cancelMediaCenterDownload:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSNumber *fileID = TGMediaCenterFileIDForItem(item);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0 ||
        ![self.mediaCenterDownloadingFileIDs containsObject:fileID]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.noActiveDownload")];
        return;
    }
    NSDictionary *request = [[self.mediaCenterSaveRequests objectForKey:fileID] retain];
    [self.mediaCenterSaveRequests removeObjectForKey:fileID];
    [self.mediaCenterDownloadingFileIDs removeObject:fileID];
    // TDLib downloads are shared by file ID. A direct Save As owns only its
    // observation; cancelling that network file could cancel an immediate retry
    // or another consumer. Its persistent wait stops when this identity is gone.
    if (![[request objectForKey:@"kind"] isEqualToString:@"save"]) {
        [[TGDownloadManager sharedManager] cancelDownloadsForFileID:fileID];
    }
    [request release];
    [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloadCancelled")];
    [self rebuildMediaCenterRowsPreservingScroll:YES];
}

- (void)saveDownloadedMediaCenterItem:(TGMessageItem *)item path:(NSString *)path
                              request:(NSDictionary *)request fileID:(NSNumber *)fileID {
    if (![self mediaCenterTransferRequestIsCurrent:request fileID:fileID]) { return; }
    NSError *error = nil;
    NSString *savedPath = [TGMediaFileActions saveCopyOfFileAtPath:path
                                                 suggestedFileName:TGMediaCenterTitleForItem(item)
                                                      shouldContinue:^BOOL {
        return [self mediaCenterTransferRequestIsCurrent:request fileID:fileID];
    } error:&error];
    // Modal dialogs run a nested event loop: account/chat/cancel can change here.
    if (![self mediaCenterTransferRequestIsCurrent:request fileID:fileID]) { return; }
    if ([savedPath length] > 0) {
        [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:
         TGLoc(@"media.center.savedAs"), [savedPath lastPathComponent]]];
    } else if (error) {
        [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:
         TGLoc(@"media.center.saveAsFailed"), [error localizedDescription]]];
    }
}

- (void)saveMediaCenterItemAs:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSNumber *fileID = TGMediaCenterFileIDForItem(item);
    NSString *path = TGMediaCenterLocalPathForItem(item);
    BOOL local = [path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!local && (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0)) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.noFileID")];
        return;
    }
    if (!self.client || ![self.currentAuthState isEqualToString:@"ready"] || !self.mediaCenterVisible) { return; }
    // Local-only files have no TDLib ID; a nonretained identity value is the request key.
    id fileIDCopy = [(fileID ? (id)fileID : (id)[NSValue valueWithNonretainedObject:item]) retain];
    if ([self.mediaCenterDownloadingFileIDs containsObject:fileIDCopy]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.alreadyDownloading")];
        [fileIDCopy release];
        return;
    }
    NSMutableDictionary *request = [self newMediaCenterTransferRequestWithKind:@"save"];
    [self.mediaCenterSaveRequests setObject:request forKey:fileIDCopy];
    [self.mediaCenterDownloadingFileIDs addObject:fileIDCopy];
    if (local) {
        [self saveDownloadedMediaCenterItem:item path:path request:request fileID:fileIDCopy];
        [self finishMediaCenterTransferRequest:request fileID:fileIDCopy];
        [request release]; [fileIDCopy release];
        return;
    }
    TGMessageItem *itemCopy = [item retain];
    TGTDLibClient *originClient = [self.client retain];
    [self rebuildMediaCenterRowsPreservingScroll:YES];
    [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloadingForSave")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *downloadedPath = [[originClient persistentDownloadedLocalPathForFileID:fileIDCopy cancelled:^BOOL {
            __block BOOL cancelled = NO;
            dispatch_sync(dispatch_get_main_queue(), ^{
                cancelled = ![self mediaCenterTransferRequestIsCurrent:request fileID:fileIDCopy];
            });
            return cancelled;
        } progress:nil error:&error] copy];
        NSString *message = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self mediaCenterTransferRequestIsCurrent:request fileID:fileIDCopy]) {
                if ([downloadedPath length] > 0) {
                    [self saveDownloadedMediaCenterItem:itemCopy path:downloadedPath request:request fileID:fileIDCopy];
                } else {
                    [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:
                     TGLoc(@"media.center.downloadFailed"), [message length] > 0 ? message : TGLoc(@"downloads.unavailable")]];
                }
            }
            [self finishMediaCenterTransferRequest:request fileID:fileIDCopy];
            [message release]; [downloadedPath release]; [request release];
            [originClient release]; [fileIDCopy release]; [itemCopy release];
        });
        [pool drain];
    });
}
