#import "TGDownloadQueueStore.h"

NSString * const TGDownloadQueueRecordsDefaultsKey = @"TelegraphicaDownloadQueueRecordsV1";

static id TGDownloadQueueValue(NSDictionary *record, NSString *key, Class expectedClass) {
    id value = [record objectForKey:key];
    return [value isKindOfClass:expectedClass] ? value : nil;
}

static NSDictionary *TGDownloadQueueSanitizedRecord(NSDictionary *record, BOOL restoring) {
    if (![record isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *identifier = TGDownloadQueueValue(record, @"identifier", [NSString class]);
    NSString *fileName = TGDownloadQueueValue(record, @"file_name", [NSString class]);
    NSString *state = TGDownloadQueueValue(record, @"state", [NSString class]);
    NSNumber *fileID = TGDownloadQueueValue(record, @"file_id", [NSNumber class]);
    NSString *fallbackPath = TGDownloadQueueValue(record, @"fallback_path", [NSString class]);
    if ([identifier length] == 0 || [fileName length] == 0 || [state length] == 0 ||
        (![fileID respondsToSelector:@selector(longLongValue)] && [fallbackPath length] == 0)) {
        return nil;
    }

    if (restoring && ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"])) {
        state = @"interrupted";
    }
    NSArray *allowedStates = [NSArray arrayWithObjects:@"queued", @"downloading", @"interrupted",
                              @"completed", @"failed", @"cancelled", @"paused", nil];
    if (![allowedStates containsObject:state]) {
        return nil;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   identifier, @"identifier",
                                   [fileName lastPathComponent], @"file_name",
                                   state, @"state",
                                   [NSNumber numberWithBool:NO], @"cancelled",
                                   nil];
    if ([fileID respondsToSelector:@selector(longLongValue)] && [fileID longLongValue] > 0) {
        [result setObject:[NSNumber numberWithLongLong:[fileID longLongValue]] forKey:@"file_id"];
    }

    NSArray *stringKeys = [NSArray arrayWithObjects:@"fallback_path", @"saved_path", @"error", @"remote_id", @"remote_unique_id", nil];
    NSUInteger index = 0;
    for (index = 0; index < [stringKeys count]; index++) {
        NSString *key = [stringKeys objectAtIndex:index];
        NSString *value = TGDownloadQueueValue(record, key, [NSString class]);
        if ([value length] > 0) {
            [result setObject:value forKey:key];
        }
    }
    NSNumber *accountID = TGDownloadQueueValue(record, @"account_id", [NSNumber class]);
    if ([accountID longLongValue] > 0) { [result setObject:accountID forKey:@"account_id"]; }
    BOOL untrusted = restoring && [fileID longLongValue] > 0;
    NSNumber *storedUntrusted = TGDownloadQueueValue(record, @"requires_remote_resolution", [NSNumber class]);
    if (untrusted || [storedUntrusted boolValue]) {
        [result setObject:[NSNumber numberWithBool:YES] forKey:@"requires_remote_resolution"];
    }
    for (NSString *key in [NSArray arrayWithObjects:@"downloaded_bytes", @"total_bytes", nil]) {
        NSNumber *value = TGDownloadQueueValue(record, key, [NSNumber class]);
        if (value && [value longLongValue] >= 0) { [result setObject:value forKey:key]; }
    }
    NSNumber *reconnecting = TGDownloadQueueValue(record, @"reconnecting", [NSNumber class]);
    if (reconnecting) { [result setObject:reconnecting forKey:@"reconnecting"]; }
    NSArray *dateKeys = [NSArray arrayWithObjects:@"created_at", @"finished_at", nil];
    for (index = 0; index < [dateKeys count]; index++) {
        NSString *key = [dateKeys objectAtIndex:index];
        NSDate *value = TGDownloadQueueValue(record, key, [NSDate class]);
        if (value) {
            [result setObject:value forKey:key];
        }
    }
    if (![result objectForKey:@"created_at"]) {
        [result setObject:[NSDate date] forKey:@"created_at"];
    }
    return result;
}

static NSArray *TGDownloadQueueSanitizedRecords(id records, BOOL restoring) {
    if (![records isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger finishedCount = 0;
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)records count]; index++) {
        NSDictionary *record = TGDownloadQueueSanitizedRecord([(NSArray *)records objectAtIndex:index], restoring);
        if (!record) { continue; }
        NSString *state = [record objectForKey:@"state"];
        BOOL finished = [state isEqualToString:@"completed"] || [state isEqualToString:@"failed"] ||
                        [state isEqualToString:@"cancelled"];
        // Rows are newest first. Bound completed history without losing an
        // older large transfer or Pause decision behind newer completions.
        if (finished && finishedCount >= 100) { continue; }
        if (finished) { finishedCount++; }
        [result addObject:record];
    }
    return result;
}

NSArray *TGDownloadQueueNormalizedRecords(id storedValue) {
    return TGDownloadQueueSanitizedRecords(storedValue, YES);
}

NSArray *TGDownloadQueueSerializableRecords(NSArray *records) {
    return TGDownloadQueueSanitizedRecords(records, NO);
}
