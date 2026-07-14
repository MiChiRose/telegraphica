#import "TGActiveSessionsPresentation.h"

@implementation TGActiveSessionsPresentation

+ (NSString *)localizedValueForKey:(NSString *)key
                          localize:(TGActiveSessionsLocalizationBlock)localize {
    NSString *value = localize ? localize(key) : nil;
    return [value length] > 0 ? value : key;
}

+ (NSString *)dateTextForTimestamp:(id)timestamp languageCode:(NSString *)languageCode {
    if (![timestamp respondsToSelector:@selector(doubleValue)] || [timestamp doubleValue] <= 0.0) {
        return @"";
    }

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    NSString *localeIdentifier = [languageCode isEqualToString:@"ru"] ? @"ru_RU" :
                                 ([languageCode isEqualToString:@"be"] ? @"be_BY" : @"en_US");
    NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:localeIdentifier] autorelease];
    [formatter setLocale:locale];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return [formatter stringFromDate:date];
}

+ (NSString *)statusTextForSummary:(NSDictionary *)summary
                          localize:(TGActiveSessionsLocalizationBlock)localize {
    NSArray *sessions = [summary objectForKey:@"sessions"];
    if (![sessions isKindOfClass:[NSArray class]]) {
        sessions = [NSArray array];
    }

    NSString *countFormat = [self localizedValueForKey:@"settings.sessions.count" localize:localize];
    NSString *statusText = [NSString stringWithFormat:countFormat, (unsigned long)[sessions count]];
    id ttlDays = [summary objectForKey:@"inactive_session_ttl_days"];
    if ([ttlDays respondsToSelector:@selector(integerValue)]) {
        NSString *ttlFormat = [self localizedValueForKey:@"settings.sessions.ttl" localize:localize];
        statusText = [statusText stringByAppendingFormat:@"  •  %@",
                      [NSString stringWithFormat:ttlFormat, (long)[ttlDays integerValue]]];
    }
    return statusText;
}

+ (NSAttributedString *)detailsTextForSummary:(NSDictionary *)summary
                                  languageCode:(NSString *)languageCode
                                      localize:(TGActiveSessionsLocalizationBlock)localize
                                     textColor:(NSColor *)textColor
                                    mutedColor:(NSColor *)mutedColor {
    NSArray *sessions = [summary objectForKey:@"sessions"];
    if (![sessions isKindOfClass:[NSArray class]]) {
        sessions = [NSArray array];
    }

    NSColor *safeTextColor = textColor ? textColor : [NSColor textColor];
    NSColor *safeMutedColor = mutedColor ? mutedColor : [NSColor disabledControlTextColor];
    NSMutableAttributedString *output = [[[NSMutableAttributedString alloc] init] autorelease];
    NSUInteger index = 0;
    for (index = 0; index < [sessions count]; index++) {
        NSDictionary *session = [sessions objectAtIndex:index];
        if (![session isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *device = [session objectForKey:@"device_model"];
        NSString *application = [session objectForKey:@"application_name"];
        NSString *version = [session objectForKey:@"application_version"];
        NSString *platform = [session objectForKey:@"platform"];
        NSString *systemVersion = [session objectForKey:@"system_version"];
        NSString *location = [session objectForKey:@"location"];
        BOOL current = [[session objectForKey:@"is_current"] boolValue];
        NSString *unknownDevice = [self localizedValueForKey:@"settings.sessions.unknownDevice" localize:localize];
        NSString *title = ([device length] > 0) ? device : (([application length] > 0) ? application : unknownDevice);
        if (current) {
            NSString *currentText = [self localizedValueForKey:@"settings.sessions.current" localize:localize];
            title = [title stringByAppendingFormat:@"  —  %@", currentText];
        }
        if ([output length] > 0) {
            [output appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
        }

        NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont boldSystemFontOfSize:14.0], NSFontAttributeName,
                                         safeTextColor, NSForegroundColorAttributeName,
                                         nil];
        [output appendAttributedString:[[[NSAttributedString alloc] initWithString:[title stringByAppendingString:@"\n"]
                                                                        attributes:titleAttributes] autorelease]];

        NSMutableArray *applicationParts = [NSMutableArray array];
        if ([application length] > 0) [applicationParts addObject:application];
        if ([version length] > 0) [applicationParts addObject:version];
        NSMutableArray *systemParts = [NSMutableArray array];
        if ([platform length] > 0) [systemParts addObject:platform];
        if ([systemVersion length] > 0) [systemParts addObject:systemVersion];

        NSMutableArray *detailLines = [NSMutableArray array];
        if ([applicationParts count] > 0) [detailLines addObject:[applicationParts componentsJoinedByString:@" "]];
        if ([systemParts count] > 0) [detailLines addObject:[systemParts componentsJoinedByString:@" • "]];
        if ([location length] > 0) [detailLines addObject:location];
        NSString *lastActive = [self dateTextForTimestamp:[session objectForKey:@"last_active_date"]
                                             languageCode:languageCode];
        if ([lastActive length] > 0) {
            NSString *lastActiveFormat = [self localizedValueForKey:@"settings.sessions.lastActive" localize:localize];
            [detailLines addObject:[NSString stringWithFormat:lastActiveFormat, lastActive]];
        }

        if ([detailLines count] > 0) {
            NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                              safeMutedColor, NSForegroundColorAttributeName,
                                              nil];
            NSString *details = [[detailLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
            [output appendAttributedString:[[[NSAttributedString alloc] initWithString:details
                                                                            attributes:detailAttributes] autorelease]];
        }
    }

    if ([sessions count] == 0) {
        NSDictionary *emptyAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont systemFontOfSize:13.0], NSFontAttributeName,
                                         safeMutedColor, NSForegroundColorAttributeName,
                                         nil];
        NSString *emptyText = [self localizedValueForKey:@"settings.sessions.empty" localize:localize];
        [output appendAttributedString:[[[NSAttributedString alloc] initWithString:emptyText
                                                                        attributes:emptyAttributes] autorelease]];
    }
    return output;
}

@end
