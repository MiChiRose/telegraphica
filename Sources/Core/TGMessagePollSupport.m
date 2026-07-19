#import "TGMessagePollSupport.h"

NSString * const TGMessagePollQuestionKey = @"question";
NSString * const TGMessagePollOptionsKey = @"options";
NSString * const TGMessagePollTotalVoterCountKey = @"total_voter_count";
NSString * const TGMessagePollClosedKey = @"is_closed";
NSString * const TGMessagePollAnonymousKey = @"is_anonymous";
NSString * const TGMessagePollMultipleChoiceKey = @"allow_multiple_answers";
NSString * const TGMessagePollQuizKey = @"is_quiz";
NSString * const TGMessagePollIDKey = @"id";

NSString * const TGMessagePollOptionTextKey = @"text";
NSString * const TGMessagePollOptionVoteCountKey = @"vote_count";
NSString * const TGMessagePollOptionChosenKey = @"is_chosen";
NSString * const TGMessagePollOptionBeingChosenKey = @"is_being_chosen";

static NSString *TGMessagePollTrimmedString(NSString *string, NSUInteger maximumLength) {
    if (![string isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] <= maximumLength || maximumLength == 0) {
        return trimmed;
    }
    NSString *prefix = [trimmed substringToIndex:maximumLength];
    return [prefix stringByAppendingString:@"..."];
}

NSString *TGMessagePollTextFromFormattedObject(id object) {
    if ([object isKindOfClass:[NSString class]]) {
        return TGMessagePollTrimmedString((NSString *)object, 4060);
    }
    if (![object isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id text = [(NSDictionary *)object objectForKey:@"text"];
    if (![text isKindOfClass:[NSString class]]) {
        return @"";
    }
    return TGMessagePollTrimmedString((NSString *)text, 4060);
}

static NSDictionary *TGMessagePollOptionInfoFromObject(id optionObject) {
    if (![optionObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *option = (NSDictionary *)optionObject;
    NSString *text = TGMessagePollTextFromFormattedObject([option objectForKey:@"text"]);
    if ([text length] == 0) {
        text = @"Option";
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:text forKey:TGMessagePollOptionTextKey];
    id voteCount = [option objectForKey:@"vote_count"];
    [info setObject:([voteCount respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[voteCount integerValue]] : [NSNumber numberWithInteger:0])
             forKey:TGMessagePollOptionVoteCountKey];
    id chosen = [option objectForKey:@"is_chosen"];
    [info setObject:[NSNumber numberWithBool:([chosen respondsToSelector:@selector(boolValue)] && [chosen boolValue])]
             forKey:TGMessagePollOptionChosenKey];
    id beingChosen = [option objectForKey:@"is_being_chosen"];
    [info setObject:[NSNumber numberWithBool:([beingChosen respondsToSelector:@selector(boolValue)] && [beingChosen boolValue])]
             forKey:TGMessagePollOptionBeingChosenKey];
    return info;
}

NSDictionary *TGMessagePollInfoFromContentObject(id contentObject) {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *content = (NSDictionary *)contentObject;
    id contentType = [content objectForKey:@"@type"];
    if (![contentType isKindOfClass:[NSString class]] || ![(NSString *)contentType isEqualToString:@"messagePoll"]) {
        return nil;
    }
    id pollObject = [content objectForKey:@"poll"];
    if (![pollObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *poll = (NSDictionary *)pollObject;
    NSString *question = TGMessagePollTextFromFormattedObject([poll objectForKey:@"question"]);
    if ([question length] == 0) {
        question = @"Poll";
    }

    NSMutableArray *options = [NSMutableArray array];
    id optionsObject = [poll objectForKey:@"options"];
    if ([optionsObject isKindOfClass:[NSArray class]]) {
        NSUInteger index = 0;
        for (index = 0; index < [(NSArray *)optionsObject count]; index++) {
            NSDictionary *optionInfo = TGMessagePollOptionInfoFromObject([(NSArray *)optionsObject objectAtIndex:index]);
            if (optionInfo) {
                [options addObject:optionInfo];
            }
        }
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:question forKey:TGMessagePollQuestionKey];
    [info setObject:options forKey:TGMessagePollOptionsKey];
    id total = [poll objectForKey:@"total_voter_count"];
    [info setObject:([total respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[total integerValue]] : [NSNumber numberWithInteger:0])
             forKey:TGMessagePollTotalVoterCountKey];
    id closed = [poll objectForKey:@"is_closed"];
    [info setObject:[NSNumber numberWithBool:([closed respondsToSelector:@selector(boolValue)] && [closed boolValue])]
             forKey:TGMessagePollClosedKey];
    id anonymous = [poll objectForKey:@"is_anonymous"];
    [info setObject:[NSNumber numberWithBool:(![anonymous respondsToSelector:@selector(boolValue)] || [anonymous boolValue])]
             forKey:TGMessagePollAnonymousKey];
    id pollID = [poll objectForKey:@"id"];
    if ([pollID respondsToSelector:@selector(longLongValue)]) {
        [info setObject:[NSNumber numberWithLongLong:[pollID longLongValue]] forKey:TGMessagePollIDKey];
    }

    id typeObject = [poll objectForKey:@"type"];
    if ([typeObject isKindOfClass:[NSDictionary class]]) {
        NSString *pollType = [(NSDictionary *)typeObject objectForKey:@"@type"];
        BOOL isQuiz = [pollType isKindOfClass:[NSString class]] && [pollType isEqualToString:@"pollTypeQuiz"];
        [info setObject:[NSNumber numberWithBool:isQuiz] forKey:TGMessagePollQuizKey];
        id multiple = [(NSDictionary *)typeObject objectForKey:@"allow_multiple_answers"];
        [info setObject:[NSNumber numberWithBool:(!isQuiz && [multiple respondsToSelector:@selector(boolValue)] && [multiple boolValue])]
                 forKey:TGMessagePollMultipleChoiceKey];
    } else {
        [info setObject:[NSNumber numberWithBool:NO] forKey:TGMessagePollQuizKey];
        [info setObject:[NSNumber numberWithBool:NO] forKey:TGMessagePollMultipleChoiceKey];
    }
    return info;
}

NSString *TGMessagePollPreviewTextFromInfo(NSDictionary *pollInfo) {
    if (![pollInfo isKindOfClass:[NSDictionary class]]) {
        return @"Poll";
    }
    NSString *question = [pollInfo objectForKey:TGMessagePollQuestionKey];
    if ([question length] > 0) {
        return question;
    }
    return @"Poll";
}
