#import "TGStatusSupport.h"

static NSString *TGVersionWithoutLeadingV(NSString *version) {
    if (![version isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *trimmed = [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] > 1 && ([[trimmed substringToIndex:1] caseInsensitiveCompare:@"v"] == NSOrderedSame)) {
        return [trimmed substringFromIndex:1];
    }
    return trimmed;
}

static NSArray *TGNumericVersionComponents(NSString *version) {
    NSString *clean = TGVersionWithoutLeadingV(version);
    NSMutableArray *numbers = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < [clean length]; index++) {
        unichar character = [clean characterAtIndex:index];
        if (character >= '0' && character <= '9') {
            [current appendFormat:@"%C", character];
        } else {
            if ([current length] > 0) {
                [numbers addObject:[NSNumber numberWithInteger:[current integerValue]]];
                [current setString:@""];
            }
            if (character == '-') {
                break;
            }
        }
    }
    if ([current length] > 0) {
        [numbers addObject:[NSNumber numberWithInteger:[current integerValue]]];
    }
    return numbers;
}

static NSString *TGVersionPrereleaseSuffix(NSString *version) {
    NSString *clean = TGVersionWithoutLeadingV(version);
    NSRange separatorRange = [clean rangeOfString:@"-"];
    if (separatorRange.location == NSNotFound || NSMaxRange(separatorRange) >= [clean length]) {
        return @"";
    }
    return [clean substringFromIndex:NSMaxRange(separatorRange)];
}

BOOL TGVersionStringIsNewer(NSString *candidate, NSString *current) {
    NSArray *candidateNumbers = TGNumericVersionComponents(candidate);
    NSArray *currentNumbers = TGNumericVersionComponents(current);
    NSUInteger count = MAX([candidateNumbers count], [currentNumbers count]);
    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        NSInteger candidateValue = (index < [candidateNumbers count]) ? [[candidateNumbers objectAtIndex:index] integerValue] : 0;
        NSInteger currentValue = (index < [currentNumbers count]) ? [[currentNumbers objectAtIndex:index] integerValue] : 0;
        if (candidateValue > currentValue) {
            return YES;
        }
        if (candidateValue < currentValue) {
            return NO;
        }
    }

    NSString *candidatePrerelease = TGVersionPrereleaseSuffix(candidate);
    NSString *currentPrerelease = TGVersionPrereleaseSuffix(current);
    BOOL candidateIsPrerelease = ([candidatePrerelease length] > 0);
    BOOL currentIsPrerelease = ([currentPrerelease length] > 0);
    if (!candidateIsPrerelease && currentIsPrerelease) {
        return YES;
    }
    if (candidateIsPrerelease && !currentIsPrerelease) {
        return NO;
    }
    if (candidateIsPrerelease && currentIsPrerelease) {
        NSComparisonResult prereleaseCompare = [candidatePrerelease compare:currentPrerelease options:(NSCaseInsensitiveSearch | NSNumericSearch)];
        if (prereleaseCompare != NSOrderedSame) {
            return prereleaseCompare == NSOrderedDescending;
        }
    }

    return ([TGVersionWithoutLeadingV(candidate) compare:TGVersionWithoutLeadingV(current) options:(NSCaseInsensitiveSearch | NSNumericSearch)] == NSOrderedDescending);
}

BOOL TGUserDefaultBoolWithDefault(NSString *key, BOOL defaultValue) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!value) {
        return defaultValue;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

BOOL TGStatusErrorLooksOffline(NSString *message) {
    if (![message isKindOfClass:[NSString class]] || [message length] == 0) {
        return NO;
    }
    NSString *lowercase = [message lowercaseString];
    NSArray *markers = [NSArray arrayWithObjects:
                        @"offline",
                        @"network",
                        @"internet",
                        @"connection",
                        @"connect",
                        @"timed out",
                        @"timeout",
                        @"socket",
                        @"posix",
                        @"unreachable",
                        @"temporarily unavailable",
                        nil];
    NSUInteger index = 0;
    for (index = 0; index < [markers count]; index++) {
        if ([lowercase rangeOfString:[markers objectAtIndex:index]].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}


NSString *TGCurrentYearString(void) {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%ld", (long)[components year]];
}

NSString *TGLogTimestampString(void) {
    return [NSDateFormatter localizedStringFromDate:[NSDate date]
                                          dateStyle:NSDateFormatterNoStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

NSString *TGLogSectionForDetail(NSString *detail) {
    if (![detail isKindOfClass:[NSString class]] || [detail length] == 0) {
        return @"Activity";
    }
    if ([detail hasPrefix:@"TDLib"] || [detail hasPrefix:@"Loaded:"] || [detail hasPrefix:@"Connecting to Telegram core"]) {
        return @"Telegram Core";
    }
    if ([detail hasPrefix:@"Submitting"] || [detail hasPrefix:@"Login"] || [detail hasPrefix:@"Logout"]) {
        return @"Account";
    }
    if ([detail hasPrefix:@"Loading"] || [detail hasPrefix:@"Select a chat"] || [detail hasPrefix:@"Message text"]) {
        return @"Chat Activity";
    }
    if ([detail hasPrefix:@"Theme changed"] || [detail hasPrefix:@"Opened message link"]) {
        return @"Interface";
    }
    if ([detail hasPrefix:@"Profile"]) {
        return @"Profile";
    }
    return @"Activity";
}
