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
        (![fileID respondsToSelector:@selector(integerValue)] && [fallbackPath length] == 0)) {
        return nil;
    }

    if (restoring && ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"])) {
        state = @"interrupted";
    }
    NSArray *allowedStates = [NSArray arrayWithObjects:@"queued", @"downloading", @"interrupted",
                              @"completed", @"failed", @"cancelled", nil];
    if (![allowedStates containsObject:state]) {
        return nil;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   identifier, @"identifier",
                                   [fileName lastPathComponent], @"file_name",
                                   state, @"state",
                                   [NSNumber numberWithBool:NO], @"cancelled",
                                   nil];
    if ([fileID respondsToSelector:@selector(integerValue)] && [fileID integerValue] > 0) {
        [result setObject:[NSNumber numberWithInteger:[fileID integerValue]] forKey:@"file_id"];
    }

    NSArray *stringKeys = [NSArray arrayWithObjects:@"fallback_path", @"saved_path", @"error", nil];
    NSUInteger index = 0;
    for (index = 0; index < [stringKeys count]; index++) {
        NSString *key = [stringKeys objectAtIndex:index];
        NSString *value = TGDownloadQueueValue(record, key, [NSString class]);
        if ([value length] > 0) {
            [result setObject:value forKey:key];
        }
    }
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

NSArray *TGDownloadQueueNormalizedRecords(id storedValue) {
    if (![storedValue isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger limit = MIN([(NSArray *)storedValue count], (NSUInteger)100);
    NSUInteger index = 0;
    for (index = 0; index < limit; index++) {
        NSDictionary *record = TGDownloadQueueSanitizedRecord([(NSArray *)storedValue objectAtIndex:index], YES);
        if (record) {
            [result addObject:record];
        }
    }
    return result;
}

NSArray *TGDownloadQueueSerializableRecords(NSArray *records) {
    if (![records isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger limit = MIN([records count], (NSUInteger)100);
    NSUInteger index = 0;
    for (index = 0; index < limit; index++) {
        NSDictionary *record = TGDownloadQueueSanitizedRecord([records objectAtIndex:index], NO);
        if (record) {
            [result addObject:record];
        }
    }
    return result;
}

