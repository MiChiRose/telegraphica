#import <Foundation/Foundation.h>
#import "TGTDLibClient+Files.h"

@implementation TGTDLibClient
@end

@interface TGFileProbeClient : TGTDLibClient {
    NSMutableArray *_capturedRequests;
    NSDictionary *_response;
}
@property (nonatomic, retain) NSMutableArray *capturedRequests;
@property (nonatomic, retain) NSDictionary *response;
@end

@implementation TGFileProbeClient

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
    return [NSError errorWithDomain:@"TGFileProbe"
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:description
                                                                forKey:NSLocalizedDescriptionKey]];
}

- (NSString *)completedLocalPathFromFileObject:(id)fileObject {
    id local = [fileObject objectForKey:@"local"];
    id path = [local objectForKey:@"path"];
    id complete = [local objectForKey:@"is_downloading_completed"];
    return ([complete boolValue] && [path isKindOfClass:[NSString class]]) ? path : nil;
}

@end

static void TGFileAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "TDLib file request probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGFileProbeClient *client = [[[TGFileProbeClient alloc] init] autorelease];
    NSNumber *fileID = [NSNumber numberWithInt:77];
    NSDictionary *local = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"/private/tmp/file.bin", @"path",
                           [NSNumber numberWithBool:YES], @"is_downloading_completed",
                           nil];
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"file", @"@type",
                       local, @"local",
                       nil];

    NSString *path = [client downloadedLocalPathForFileID:fileID timeout:2.0 error:NULL];
    TGFileAssert([path isEqualToString:@"/private/tmp/file.bin"], @"completed path should be returned");
    NSDictionary *downloadRequest = [client.capturedRequests lastObject];
    TGFileAssert([[downloadRequest objectForKey:@"@type"] isEqualToString:@"downloadFile"], @"download request type");
    TGFileAssert([[downloadRequest objectForKey:@"priority"] integerValue] == 16, @"download priority");
    TGFileAssert([[downloadRequest objectForKey:@"synchronous"] boolValue], @"worker request must await completion");

    client.response = [NSDictionary dictionaryWithObject:@"ok" forKey:@"@type"];
    TGFileAssert([client cancelDownloadForFileID:fileID timeout:2.0 error:NULL], @"cancel response");
    NSDictionary *cancelRequest = [client.capturedRequests lastObject];
    TGFileAssert([[cancelRequest objectForKey:@"@type"] isEqualToString:@"cancelDownloadFile"], @"cancel request type");
    TGFileAssert(![[cancelRequest objectForKey:@"only_if_pending"] boolValue], @"active transfers can be cancelled");

    TGFileAssert([client deleteCachedFileForFileID:fileID timeout:2.0 error:NULL], @"delete response");
    NSDictionary *deleteRequest = [client.capturedRequests lastObject];
    TGFileAssert([[deleteRequest objectForKey:@"@type"] isEqualToString:@"deleteFile"], @"delete request type");

    NSError *invalidError = nil;
    TGFileAssert(![client cancelDownloadForFileID:[NSNumber numberWithInt:0] timeout:2.0 error:&invalidError],
                 @"invalid file identifier should be rejected");
    TGFileAssert(invalidError != nil, @"invalid file identifier should provide an error");

    printf("TDLib file request probe passed.\n");
    [pool drain];
    return 0;
}
