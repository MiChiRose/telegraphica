#import "TGWorkshopPackageDownloader.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../Catalog/TGWorkshopConfiguration.h"
#import "../Host/TGWorkshopPaths.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../../UI/TGUpdateSupport.h"

static NSError *TGWorkshopDownloadError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSURL *TGWorkshopResolvedPackageURL(NSURL *catalogURL) {
    NSString *host = [[catalogURL host] lowercaseString];
    NSString *path = [catalogURL path];
    NSString *prefix = @"/MiChiRose/telegraphica/releases/download/workshop-modules-v1/";
    if (![host isEqualToString:@"github.com"] || ![path hasPrefix:prefix]) {
        return catalogURL;
    }
    NSString *asset = [path substringFromIndex:[prefix length]];
    if ([asset length] == 0 || [asset rangeOfString:@"/"].location != NSNotFound) {
        return catalogURL;
    }
    NSString *escapedAsset = [asset stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *workerURL = [NSString stringWithFormat:
                           @"https://telegraphica-tdlib-config.telegraphica.workers.dev/v1/workshop/package?asset=%@",
                           escapedAsset];
    return [NSURL URLWithString:workerURL];
}

@implementation TGWorkshopPackageDownloader

- (BOOL)URLIsAllowed:(NSURL *)URL {
    return [[[URL scheme] lowercaseString] isEqualToString:@"https"] &&
           [TGWorkshopAllowedDownloadHosts() containsObject:[[URL host] lowercaseString]];
}

- (void)downloadCatalogEntry:(TGWorkshopCatalogEntry *)entry
                    progress:(TGWorkshopDownloadProgress)progress
                  completion:(TGWorkshopDownloadCompletion)completion {
    [self cancel];
    NSURL *downloadURL = entry ? TGWorkshopResolvedPackageURL([entry downloadURL]) : nil;
    if (!entry || ![self URLIsAllowed:downloadURL] || !TGWorkshopEnsureBaseDirectories(NULL)) {
        if (completion) completion(nil, TGWorkshopDownloadError(370, @"Workshop module download URL is not trusted."));
        return;
    }

    _entry = [entry retain];
    _progress = [progress copy];
    _completion = [completion copy];
    _receivedBytes = 0;
    _partialPath = [[TGWorkshopDownloadsDirectory() stringByAppendingPathComponent:
                     [[entry moduleIdentifier] stringByAppendingFormat:@"-%@.partial", [entry version]]] copy];
    [[NSFileManager defaultManager] removeItemAtPath:_partialPath error:NULL];
    _outputStream = [[NSOutputStream outputStreamToFileAtPath:_partialPath append:NO] retain];
    [_outputStream open];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:60.0];
    [request setValue:TGUpdateCheckUserAgentString() forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/zip" forHTTPHeaderField:@"Accept"];
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
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

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    (void)connection;
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    long long expected = [response expectedContentLength];
    if (statusCode != 200 || (expected >= 0 && (unsigned long long)expected != [_entry archiveSize])) {
        [connection cancel];
        [self finishWithPath:nil error:TGWorkshopDownloadError(371, @"Workshop module server returned an unexpected package.")];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    (void)connection;
    if (_receivedBytes + [data length] > [_entry archiveSize]) {
        [connection cancel];
        [self finishWithPath:nil error:TGWorkshopDownloadError(372, @"Workshop module download exceeded its signed size.")];
        return;
    }
    const uint8_t *bytes = [data bytes];
    NSUInteger remaining = [data length];
    while (remaining > 0) {
        NSInteger written = [_outputStream write:bytes maxLength:remaining];
        if (written <= 0) {
            [connection cancel];
            [self finishWithPath:nil error:[_outputStream streamError] ? [_outputStream streamError] :
             TGWorkshopDownloadError(373, @"Workshop module download could not be saved.")];
            return;
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    _receivedBytes += [data length];
    if (_progress) _progress(_receivedBytes, [_entry archiveSize]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    (void)connection;
    [_outputStream close];
    [_outputStream release];
    _outputStream = nil;
    if (_receivedBytes != [_entry archiveSize]) {
        [self finishWithPath:nil error:TGWorkshopDownloadError(374, @"Workshop module download is incomplete.")];
        return;
    }
    NSString *completedPath = [_partialPath stringByDeletingPathExtension];
    [[NSFileManager defaultManager] removeItemAtPath:completedPath error:NULL];
    NSError *moveError = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:_partialPath toPath:completedPath error:&moveError]) {
        [self finishWithPath:nil error:moveError];
        return;
    }
    [self finishWithPath:completedPath error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    (void)connection;
    [self finishWithPath:nil error:error];
}

- (void)finishWithPath:(NSString *)path error:(NSError *)error {
    if (_outputStream) {
        [_outputStream close];
        [_outputStream release];
        _outputStream = nil;
    }
    if (error && [_partialPath length] > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:_partialPath error:NULL];
    }
    TGWorkshopDownloadCompletion completion = [_completion autorelease];
    _completion = nil;
    [_progress release];
    _progress = nil;
    [_connection release];
    _connection = nil;
    [_entry release];
    _entry = nil;
    [_partialPath release];
    _partialPath = nil;
    if (completion) completion(path, error);
}

- (void)cancel {
    [_connection cancel];
    if (_outputStream) [_outputStream close];
    if ([_partialPath length] > 0) [[NSFileManager defaultManager] removeItemAtPath:_partialPath error:NULL];
    [_entry release];
    _entry = nil;
    [_connection release];
    _connection = nil;
    [_outputStream release];
    _outputStream = nil;
    [_partialPath release];
    _partialPath = nil;
    [_progress release];
    _progress = nil;
    [_completion release];
    _completion = nil;
    _receivedBytes = 0;
}

- (void)dealloc {
    [self cancel];
    [super dealloc];
}

@end
