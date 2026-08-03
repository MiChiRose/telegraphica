#import <Foundation/Foundation.h>
#import "TGTDLibClient+Storage.h"

@implementation TGTDLibClient
@end

@interface TGStorageProbeClient : TGTDLibClient {
    NSMutableArray *_capturedRequests;
    NSMutableArray *_responses;
}
@property (nonatomic, retain) NSMutableArray *capturedRequests;
@property (nonatomic, retain) NSMutableArray *responses;
@end

@implementation TGStorageProbeClient

@synthesize capturedRequests = _capturedRequests;
@synthesize responses = _responses;

- (id)init {
    self = [super init];
    if (self) {
        self.capturedRequests = [NSMutableArray array];
        self.responses = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [_capturedRequests release];
    [_responses release];
    [super dealloc];
}

- (NSString *)uniqueExtraWithPrefix:(NSString *)prefix {
    return [NSString stringWithFormat:@"%@-probe", prefix];
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
    if ([self.responses count] == 0) {
        return nil;
    }
    NSDictionary *response = [[self.responses objectAtIndex:0] retain];
    [self.responses removeObjectAtIndex:0];
    return [response autorelease];
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    return [NSError errorWithDomain:@"TGStorageProbe"
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:description
                                                                forKey:NSLocalizedDescriptionKey]];
}

@end

static void TGStorageAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "TDLib storage request probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

static NSDictionary *TGStorageStatistics(long long filesSize, long long databaseSize) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"storageStatisticsFast", @"@type",
            [NSNumber numberWithLongLong:filesSize], @"files_size",
            [NSNumber numberWithLongLong:databaseSize], @"database_size",
            [NSNumber numberWithLongLong:3], @"language_pack_database_size",
            [NSNumber numberWithLongLong:4], @"log_size",
            nil];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGStorageProbeClient *client = [[[TGStorageProbeClient alloc] init] autorelease];
    [client.responses addObject:TGStorageStatistics(10, 20)];

    NSDictionary *summary = [client storageUsageSummaryWithTimeout:2.0 error:NULL];
    TGStorageAssert([[summary objectForKey:@"total_size"] longLongValue] == 37LL,
                    @"fast statistics should produce a bounded summary");
    NSDictionary *statisticsRequest = [client.capturedRequests objectAtIndex:0];
    TGStorageAssert([[statisticsRequest objectForKey:@"@type"] isEqualToString:@"getStorageStatisticsFast"],
                    @"storage request type");

    [client.capturedRequests removeAllObjects];
    NSDictionary *photoType = [NSDictionary dictionaryWithObject:@"fileTypePhoto" forKey:@"@type"];
    [client.responses addObject:[NSDictionary dictionaryWithObject:@"ok" forKey:@"@type"]];
    [client.responses addObject:TGStorageStatistics(1, 2)];
    NSDictionary *clearedSummary = [client clearDownloadedMediaCacheForFileTypes:[NSArray arrayWithObject:photoType]
                                                                          chatIDs:[NSArray arrayWithObjects:
                                                                                   [NSNumber numberWithLongLong:42],
                                                                                   [NSNumber numberWithLongLong:42],
                                                                                   [NSNumber numberWithLongLong:0],
                                                                                   nil]
                                                                          timeout:2.0
                                                                            error:NULL];
    TGStorageAssert([[clearedSummary objectForKey:@"total_size"] longLongValue] == 10LL,
                    @"cleanup should refresh storage totals");
    TGStorageAssert([client.capturedRequests count] == 2,
                    @"cleanup should be followed by one statistics refresh");
    NSDictionary *cleanupRequest = [client.capturedRequests objectAtIndex:0];
    TGStorageAssert([[cleanupRequest objectForKey:@"@type"] isEqualToString:@"optimizeStorage"],
                    @"cleanup request type");
    TGStorageAssert([[cleanupRequest objectForKey:@"file_types"] count] == 1,
                    @"file type filter should be preserved");
    TGStorageAssert([[cleanupRequest objectForKey:@"chat_ids"] count] == 1,
                    @"chat identifiers should be normalized and deduplicated");
    TGStorageAssert([[cleanupRequest objectForKey:@"chat_limit"] unsignedIntegerValue] == 1,
                    @"chat limit should match normalized scope");
    TGStorageAssert(![[cleanupRequest objectForKey:@"return_deleted_file_statistics"] boolValue],
                    @"cleanup should avoid expensive deleted-file statistics");

    printf("TDLib storage request probe passed.\n");
    [pool drain];
    return 0;
}
