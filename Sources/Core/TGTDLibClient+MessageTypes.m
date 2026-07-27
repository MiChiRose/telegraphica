#import "TGTDLibClient+MessageTypes.h"

@interface TGTDLibClient (MessageTypesPrivate)
- (NSString *)sendStructuredMessageToChatID:(NSNumber *)chatID
                             messageThreadID:(NSNumber *)messageThreadID
                            messageTopicKind:(NSString *)messageTopicKind
                              currentContent:(NSDictionary *)currentContent
                               legacyContent:(NSDictionary *)legacyContent
                            replyToMessageID:(NSNumber *)replyToMessageID
                                       label:(NSString *)label
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error;
- (NSDictionary *)sendMessageRequest:(NSDictionary *)request
                     messageThreadID:(NSNumber *)messageThreadID
                    messageTopicKind:(NSString *)messageTopicKind
                         extraPrefix:(NSString *)extraPrefix
                             timeout:(NSTimeInterval)timeout
                           errorCode:(NSInteger)errorCode
                               error:(NSError **)error;
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

static NSDictionary *TGMessageTypeLocation(double latitude, double longitude) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"location", @"@type",
            [NSNumber numberWithDouble:latitude], @"latitude",
            [NSNumber numberWithDouble:longitude], @"longitude",
            [NSNumber numberWithDouble:0.0], @"horizontal_accuracy",
            nil];
}

static NSDictionary *TGMessageTypeFormattedText(NSString *text) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"formattedText", @"@type",
            (text ? text : @""), @"text",
            [NSArray array], @"entities",
            nil];
}

static BOOL TGMessageTypeCoordinatesValid(double latitude, double longitude) {
    return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0;
}

@implementation TGTDLibClient (MessageTypes)

- (NSString *)sendVideoNoteMessageToChatID:(NSNumber *)chatID
                           messageThreadID:(NSNumber *)messageThreadID
                          messageTopicKind:(NSString *)messageTopicKind
                                 localPath:(NSString *)localPath
                          replyToMessageID:(NSNumber *)replyToMessageID
                                   timeout:(NSTimeInterval)timeout
                                     error:(NSError **)error {
    NSString *path = [localPath isKindOfClass:[NSString class]] ? [localPath stringByStandardizingPath] : @"";
    BOOL directory = NO;
    if ([path length] == 0 ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory] || directory) {
        if (error) {
            *error = [self errorWithDescription:@"Video note file does not exist." code:420];
        }
        return nil;
    }
    NSDictionary *file = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"inputFileLocal", @"@type", path, @"path", nil];
    NSDictionary *current = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"inputMessageVideoNote", @"@type",
                             file, @"video_note",
                             [NSNull null], @"thumbnail",
                             [NSNumber numberWithInt:0], @"duration",
                             [NSNumber numberWithInt:384], @"length",
                             [NSNull null], @"self_destruct_type",
                             nil];
    NSDictionary *legacy = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"inputMessageVideoNote", @"@type",
                            file, @"video_note",
                            [NSNull null], @"thumbnail",
                            [NSNumber numberWithInt:0], @"duration",
                            [NSNumber numberWithInt:384], @"length",
                            nil];
    return [self sendStructuredMessageToChatID:chatID
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                 currentContent:current
                                  legacyContent:legacy
                               replyToMessageID:replyToMessageID
                                          label:@"VideoNote"
                                        timeout:timeout
                                          error:error];
}

- (NSString *)sendVenueMessageToChatID:(NSNumber *)chatID
                       messageThreadID:(NSNumber *)messageThreadID
                      messageTopicKind:(NSString *)messageTopicKind
                              latitude:(double)latitude
                             longitude:(double)longitude
                                 title:(NSString *)title
                               address:(NSString *)address
                      replyToMessageID:(NSNumber *)replyToMessageID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    NSString *safeTitle = [title isKindOfClass:[NSString class]]
        ? [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    NSString *safeAddress = [address isKindOfClass:[NSString class]]
        ? [address stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if (!TGMessageTypeCoordinatesValid(latitude, longitude) || [safeTitle length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Venue title and valid coordinates are required." code:421];
        }
        return nil;
    }
    NSDictionary *venue = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"venue", @"@type",
                           TGMessageTypeLocation(latitude, longitude), @"location",
                           safeTitle, @"title",
                           safeAddress, @"address",
                           @"", @"provider",
                           @"", @"id",
                           @"", @"type",
                           nil];
    NSDictionary *content = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"inputMessageVenue", @"@type", venue, @"venue", nil];
    return [self sendStructuredMessageToChatID:chatID
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                 currentContent:content
                                  legacyContent:content
                               replyToMessageID:replyToMessageID
                                          label:@"Venue"
                                        timeout:timeout
                                          error:error];
}

- (NSString *)sendLiveLocationMessageToChatID:(NSNumber *)chatID
                              messageThreadID:(NSNumber *)messageThreadID
                             messageTopicKind:(NSString *)messageTopicKind
                                     latitude:(double)latitude
                                    longitude:(double)longitude
                                   livePeriod:(NSInteger)livePeriod
                             replyToMessageID:(NSNumber *)replyToMessageID
                                      timeout:(NSTimeInterval)timeout
                                        error:(NSError **)error {
    if (!TGMessageTypeCoordinatesValid(latitude, longitude) || livePeriod < 60 || livePeriod > 86400) {
        if (error) {
            *error = [self errorWithDescription:@"Live location coordinates or duration are invalid." code:422];
        }
        return nil;
    }
    NSDictionary *content = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"inputMessageLocation", @"@type",
                             TGMessageTypeLocation(latitude, longitude), @"location",
                             [NSNumber numberWithInteger:livePeriod], @"live_period",
                             [NSNumber numberWithInt:0], @"heading",
                             [NSNumber numberWithInt:0], @"proximity_alert_radius",
                             nil];
    return [self sendStructuredMessageToChatID:chatID
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                 currentContent:content
                                  legacyContent:content
                               replyToMessageID:replyToMessageID
                                          label:@"LiveLocation"
                                        timeout:timeout
                                          error:error];
}

- (NSString *)sendDiceMessageToChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                                emoji:(NSString *)emoji
                     replyToMessageID:(NSNumber *)replyToMessageID
                              timeout:(NSTimeInterval)timeout
                                error:(NSError **)error {
    NSArray *allowed = [NSArray arrayWithObjects:@"🎲", @"🎯", @"🏀", @"⚽", @"🎳", @"🎰", nil];
    NSString *safeEmoji = [allowed containsObject:emoji] ? emoji : @"🎲";
    NSDictionary *content = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"inputMessageDice", @"@type",
                             safeEmoji, @"emoji",
                             [NSNumber numberWithBool:YES], @"clear_draft",
                             nil];
    return [self sendStructuredMessageToChatID:chatID
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                 currentContent:content
                                  legacyContent:content
                               replyToMessageID:replyToMessageID
                                          label:@"Dice"
                                        timeout:timeout
                                          error:error];
}

- (NSString *)sendQuizMessageToChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                             question:(NSString *)question
                              options:(NSArray *)options
                   correctOptionIndex:(NSInteger)correctOptionIndex
                          explanation:(NSString *)explanation
                            anonymous:(BOOL)anonymous
                              timeout:(NSTimeInterval)timeout
                                error:(NSError **)error {
    NSString *safeQuestion = [question isKindOfClass:[NSString class]]
        ? [question stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    NSMutableArray *safeOptions = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [options count] && [safeOptions count] < 10; index++) {
        NSString *option = [[options objectAtIndex:index] isKindOfClass:[NSString class]]
            ? [[options objectAtIndex:index] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        if ([option length] > 0) {
            [safeOptions addObject:option];
        }
    }
    if (![chatID respondsToSelector:@selector(longLongValue)] || [safeQuestion length] == 0 ||
        [safeOptions count] < 2 || correctOptionIndex < 0 ||
        (NSUInteger)correctOptionIndex >= [safeOptions count]) {
        if (error) {
            *error = [self errorWithDescription:@"Quiz question, options, and correct answer are required." code:423];
        }
        return nil;
    }
    NSString *safeExplanation = [explanation isKindOfClass:[NSString class]] ? explanation : @"";
    if ([safeExplanation length] > 200) {
        safeExplanation = [safeExplanation substringToIndex:200];
    }
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        return nil;
    }
    NSMutableArray *inputOptions = [NSMutableArray array];
    for (index = 0; index < [safeOptions count]; index++) {
        [inputOptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"inputPollOption", @"@type",
                                 TGMessageTypeFormattedText([safeOptions objectAtIndex:index]), @"text",
                                 nil]];
    }
    NSDictionary *pollType = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"pollTypeQuiz", @"@type",
                              [NSNumber numberWithInteger:correctOptionIndex], @"correct_option_id",
                              TGMessageTypeFormattedText(safeExplanation), @"explanation",
                              nil];
    NSDictionary *content = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"inputMessagePoll", @"@type",
                             TGMessageTypeFormattedText(safeQuestion), @"question",
                             inputOptions, @"options",
                             [NSNumber numberWithBool:anonymous], @"is_anonymous",
                             pollType, @"type",
                             [NSNumber numberWithInt:0], @"open_period",
                             [NSNumber numberWithInt:0], @"close_date",
                             [NSNumber numberWithBool:NO], @"is_closed",
                             nil];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"sendMessage", @"@type",
                             chatID, @"chat_id",
                             content, @"input_message_content",
                             nil];
    NSDictionary *response = [self sendMessageRequest:request
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-send-quiz"
                                              timeout:timeout
                                            errorCode:424
                                                error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"message"] ? @"quiz submitted" : nil;
}

@end
