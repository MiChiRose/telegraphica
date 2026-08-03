#import <Foundation/Foundation.h>
#import "TGTDLibClient+Search.h"

@implementation TGTDLibClient
@end

@interface TGSearchProbeClient : TGTDLibClient
@property (nonatomic, retain) NSMutableArray *capturedRequests;
@property (nonatomic, retain) NSDictionary *response;
@end

@implementation TGSearchProbeClient

@synthesize capturedRequests = _capturedRequests;
@synthesize response = _response;

- (id)init {
    self = [super init];
    if (self) {
        self.capturedRequests = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [_capturedRequests release];
    [_response release];
    [super dealloc];
}

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error {
    (void)extraPrefix;
    (void)timeout;
    (void)errorCode;
    (void)error;
    [self.capturedRequests addObject:request];
    return self.response;
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    return [NSError errorWithDomain:@"TGSearchProbe"
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:description
                                                                forKey:NSLocalizedDescriptionKey]];
}

- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID {
    (void)chatID;
    return messages;
}

- (NSArray *)messagesFromSearchResponse:(NSDictionary *)response error:(NSError **)error {
    (void)error;
    id messages = [response objectForKey:@"messages"];
    return [messages isKindOfClass:[NSArray class]] ? messages : nil;
}

@end

static void TGSearchAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "TDLib search request probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGSearchProbeClient *client = [[[TGSearchProbeClient alloc] init] autorelease];
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"foundMessages", @"@type",
                       [NSArray array], @"messages",
                       @"page-2", @"next_offset",
                       nil];

    NSString *offset = nil;
    NSArray *globalResults = [client globalSearchMessagePreviewItemsWithQuery:@"legacy mac"
                                                                       filter:@"voice"
                                                                       offset:&offset
                                                                        limit:500
                                                                      timeout:2.0
                                                                        error:NULL];
    TGSearchAssert([globalResults count] == 0, @"empty fixture should yield empty global results");
    NSDictionary *globalRequest = [client.capturedRequests lastObject];
    TGSearchAssert([[globalRequest objectForKey:@"@type"] isEqualToString:@"searchMessages"], @"global request type");
    TGSearchAssert([[globalRequest objectForKey:@"limit"] integerValue] == 30, @"global limit should be bounded");
    TGSearchAssert([[[globalRequest objectForKey:@"filter"] objectForKey:@"@type"] isEqualToString:@"searchMessagesFilterVoiceNote"], @"voice filter mapping");
    TGSearchAssert([offset isEqualToString:@"page-2"], @"next offset should be returned");
    [offset release];

    [client.capturedRequests removeAllObjects];
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"foundChatMessages", @"@type",
                       [NSArray array], @"messages",
                       nil];
    NSArray *chatResults = [client searchMessagePreviewItemsForChatID:[NSNumber numberWithLongLong:42]
                                                       messageThreadID:[NSNumber numberWithLongLong:77]
                                                      messageTopicKind:@"thread"
                                                                 query:@"photo"
                                                                filter:@"photos"
                                                         fromMessageID:[NSNumber numberWithLongLong:99]
                                                                 limit:12
                                                               timeout:2.0
                                                                 error:NULL];
    TGSearchAssert([chatResults count] == 0, @"empty fixture should yield empty chat results");
    NSDictionary *chatRequest = [client.capturedRequests objectAtIndex:0];
    TGSearchAssert([[chatRequest objectForKey:@"@type"] isEqualToString:@"searchChatMessages"], @"chat request type");
    TGSearchAssert([[chatRequest objectForKey:@"from_message_id"] longLongValue] == 99LL, @"chat search anchor");
    TGSearchAssert([[[chatRequest objectForKey:@"topic_id"] objectForKey:@"@type"] isEqualToString:@"messageTopicThread"], @"thread request should be tried first");
    TGSearchAssert([[[chatRequest objectForKey:@"filter"] objectForKey:@"@type"] isEqualToString:@"searchMessagesFilterPhoto"], @"photo filter mapping");

    printf("TDLib search request probe passed.\n");
    [pool drain];
    return 0;
}
