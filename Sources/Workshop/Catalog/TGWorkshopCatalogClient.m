#import "TGWorkshopCatalogClient.h"
#import "TGWorkshopCatalog.h"
#import "TGWorkshopCatalogParser.h"
#import "TGWorkshopConfiguration.h"
#import "../Host/TGWorkshopPaths.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../../UI/TGUpdateSupport.h"

static NSString * const TGWorkshopCatalogCacheFileName = @"catalog.json";
static NSString * const TGWorkshopCatalogMetadataFileName = @"metadata.plist";

static NSError *TGWorkshopCatalogClientError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSString *TGWorkshopCatalogCachePath(void) {
    return [TGWorkshopCatalogCacheDirectory() stringByAppendingPathComponent:TGWorkshopCatalogCacheFileName];
}

static NSString *TGWorkshopCatalogMetadataPath(void) {
    return [TGWorkshopCatalogCacheDirectory() stringByAppendingPathComponent:TGWorkshopCatalogMetadataFileName];
}

@implementation TGWorkshopCatalogClient

- (id)initWithParser:(TGWorkshopCatalogParser *)parser {
    self = [super init];
    if (self) {
        _parser = [parser retain];
    }
    return self;
}

- (BOOL)URLIsAllowed:(NSURL *)URL {
    return [[[URL scheme] lowercaseString] isEqualToString:@"https"] &&
           [TGWorkshopAllowedDownloadHosts() containsObject:[[URL host] lowercaseString]];
}

- (NSMutableURLRequest *)catalogRequestUsingValidators:(BOOL)useValidators {
    NSURL *URL = TGWorkshopCatalogURL();
    if (![self URLIsAllowed:URL]) {
        return nil;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    [request setValue:TGUpdateCheckUserAgentString() forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (useValidators) {
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:TGWorkshopCatalogMetadataPath()];
        NSString *ETag = [[metadata objectForKey:@"etag"] isKindOfClass:[NSString class]] ? [metadata objectForKey:@"etag"] : nil;
        NSString *lastModified = [[metadata objectForKey:@"last_modified"] isKindOfClass:[NSString class]] ? [metadata objectForKey:@"last_modified"] : nil;
        if ([ETag length] > 0) [request setValue:ETag forHTTPHeaderField:@"If-None-Match"];
        if ([lastModified length] > 0) [request setValue:lastModified forHTTPHeaderField:@"If-Modified-Since"];
    }
    return request;
}

- (void)startRequestUsingValidators:(BOOL)useValidators {
    NSMutableURLRequest *request = [self catalogRequestUsingValidators:useValidators];
    if (!request) {
        [self finishWithCatalog:nil stale:NO error:TGWorkshopCatalogClientError(230, @"Workshop catalog URL is not trusted.")];
        return;
    }
    [_responseData release];
    _responseData = [[NSMutableData alloc] init];
    [_response release];
    _response = nil;
    [_connection release];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)fetchCatalogWithCompletion:(TGWorkshopCatalogCompletion)completion {
    [self cancel];
    _completion = [completion copy];
    _retriedWithoutValidators = NO;
    if (!TGWorkshopEnsureBaseDirectories(NULL)) {
        NSError *error = nil;
        TGWorkshopCatalog *fallback = [self cachedOrBundledCatalogAllowingExpired:YES stale:NULL error:&error];
        [self finishWithCatalog:fallback stale:YES error:fallback ? nil : error];
        return;
    }
    [self startRequestUsingValidators:YES];
}

- (void)finishWithCatalog:(TGWorkshopCatalog *)catalog stale:(BOOL)stale error:(NSError *)error {
    TGWorkshopCatalogCompletion completion = [_completion autorelease];
    _completion = nil;
    [_connection release];
    _connection = nil;
    [_responseData release];
    _responseData = nil;
    [_response release];
    _response = nil;
    if (completion) {
        completion(catalog, stale, error);
    }
}

- (TGWorkshopCatalog *)catalogFromPath:(NSString *)path error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    return data ? [_parser catalogFromEnvelopeData:data error:error] : nil;
}

- (TGWorkshopCatalog *)cachedOrBundledCatalogAllowingExpired:(BOOL)allowExpired
                                                       stale:(BOOL *)stale
                                                       error:(NSError **)error {
    NSArray *paths = [NSArray arrayWithObjects:TGWorkshopCatalogCachePath(), TGWorkshopBundledCatalogPath(), nil];
    NSString *path = nil;
    NSError *lastError = nil;
    for (path in paths) {
        if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            continue;
        }
        TGWorkshopCatalog *catalog = [self catalogFromPath:path error:&lastError];
        if (catalog && (allowExpired || ![catalog isExpiredAtDate:[NSDate date]])) {
            if (stale) *stale = [catalog isExpiredAtDate:[NSDate date]];
            return catalog;
        }
    }
    if (error) *error = lastError ? lastError : TGWorkshopCatalogClientError(231, @"No verified Workshop catalog is available.");
    return nil;
}

- (BOOL)saveVerifiedCatalogData:(NSData *)data
                       response:(NSHTTPURLResponse *)response
                          error:(NSError **)error {
    if (!TGWorkshopEnsureDirectory(TGWorkshopCatalogCacheDirectory(), error)) {
        return NO;
    }
    NSString *temporaryPath = [TGWorkshopCatalogCachePath() stringByAppendingString:@".tmp"];
    if (![data writeToFile:temporaryPath options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:TGWorkshopCatalogCachePath() error:NULL];
    if (![fileManager moveItemAtPath:temporaryPath toPath:TGWorkshopCatalogCachePath() error:error]) {
        return NO;
    }
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    NSString *ETag = [[response allHeaderFields] objectForKey:@"Etag"];
    if ([ETag length] == 0) ETag = [[response allHeaderFields] objectForKey:@"ETag"];
    NSString *lastModified = [[response allHeaderFields] objectForKey:@"Last-Modified"];
    if ([ETag length] > 0) [metadata setObject:ETag forKey:@"etag"];
    if ([lastModified length] > 0) [metadata setObject:lastModified forKey:@"last_modified"];
    return [metadata writeToFile:TGWorkshopCatalogMetadataPath() atomically:YES];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    (void)connection;
    [_response release];
    _response = [(NSHTTPURLResponse *)response retain];
    [_responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    (void)connection;
    if ([_responseData length] + [data length] <= 4 * 1024 * 1024) {
        [_responseData appendData:data];
    } else {
        [connection cancel];
        [self finishWithCatalog:nil stale:NO error:TGWorkshopCatalogClientError(232, @"Workshop catalog is unexpectedly large.")];
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    (void)connection;
    if (redirectResponse && ![self URLIsAllowed:[request URL]]) {
        return nil;
    }
    return request;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    (void)connection;
    NSInteger statusCode = [_response statusCode];
    if (statusCode == 304) {
        NSError *cacheError = nil;
        TGWorkshopCatalog *catalog = [self catalogFromPath:TGWorkshopCatalogCachePath() error:&cacheError];
        if (!catalog && !_retriedWithoutValidators) {
            _retriedWithoutValidators = YES;
            [self startRequestUsingValidators:NO];
            return;
        }
        [self finishWithCatalog:catalog stale:[catalog isExpiredAtDate:[NSDate date]] error:catalog ? nil : cacheError];
        return;
    }
    if (statusCode != 200) {
        NSError *fallbackError = nil;
        BOOL stale = NO;
        TGWorkshopCatalog *fallback = [self cachedOrBundledCatalogAllowingExpired:YES stale:&stale error:&fallbackError];
        [self finishWithCatalog:fallback
                          stale:YES
                          error:fallback ? nil : TGWorkshopCatalogClientError(233, @"Workshop catalog server returned an error.")];
        return;
    }

    NSError *parseError = nil;
    TGWorkshopCatalog *catalog = [_parser catalogFromEnvelopeData:_responseData error:&parseError];
    if (!catalog || [catalog isExpiredAtDate:[NSDate date]]) {
        [self finishWithCatalog:nil stale:NO error:parseError ? parseError : TGWorkshopCatalogClientError(234, @"Workshop catalog has expired.")];
        return;
    }
    TGWorkshopCatalog *cachedCatalog = [self catalogFromPath:TGWorkshopCatalogCachePath() error:NULL];
    if (cachedCatalog && [catalog catalogVersion] < [cachedCatalog catalogVersion]) {
        [self finishWithCatalog:nil stale:NO error:TGWorkshopCatalogClientError(235, @"Workshop catalog rollback was rejected.")];
        return;
    }
    NSError *saveError = nil;
    if (![self saveVerifiedCatalogData:_responseData response:_response error:&saveError]) {
        [self finishWithCatalog:catalog stale:NO error:nil];
        return;
    }
    [self finishWithCatalog:catalog stale:NO error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)networkError {
    (void)connection;
    NSError *fallbackError = nil;
    BOOL stale = NO;
    TGWorkshopCatalog *fallback = [self cachedOrBundledCatalogAllowingExpired:YES stale:&stale error:&fallbackError];
    [self finishWithCatalog:fallback stale:YES error:fallback ? nil : networkError];
}

- (void)cancel {
    [_connection cancel];
    [_connection release];
    _connection = nil;
    [_responseData release];
    _responseData = nil;
    [_response release];
    _response = nil;
    [_completion release];
    _completion = nil;
}

- (void)dealloc {
    [self cancel];
    [_parser release];
    [super dealloc];
}

@end
