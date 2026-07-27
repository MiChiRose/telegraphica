#import "TGTDLibClient+MapThumbnail.h"

@interface TGTDLibClient (MapThumbnailPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

@implementation TGTDLibClient (MapThumbnail)

- (NSString *)mapThumbnailPathForLatitude:(double)latitude
                                longitude:(double)longitude
                                     zoom:(NSInteger)zoom
                                    width:(NSInteger)width
                                   height:(NSInteger)height
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error {
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        if (error) {
            *error = [self errorWithDescription:@"Map coordinates are invalid." code:570];
        }
        return nil;
    }
    NSInteger safeZoom = MAX(13, MIN(18, zoom));
    NSInteger safeWidth = MAX(96, MIN(1024, width));
    NSInteger safeHeight = MAX(96, MIN(1024, height));
    NSDictionary *location = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"location", @"@type",
                              [NSNumber numberWithDouble:latitude], @"latitude",
                              [NSNumber numberWithDouble:longitude], @"longitude",
                              [NSNumber numberWithDouble:0.0], @"horizontal_accuracy",
                              nil];
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    @"getMapThumbnailFile", @"@type",
                                    location, @"location",
                                    [NSNumber numberWithInteger:safeZoom], @"zoom",
                                    [NSNumber numberWithInteger:safeWidth], @"width",
                                    [NSNumber numberWithInteger:safeHeight], @"height",
                                    [NSNumber numberWithInteger:1], @"scale",
                                    [NSNumber numberWithLongLong:0], @"chat_id",
                                    nil];
    NSError *requestError = nil;
    NSDictionary *file = [self sendTDLibRequestAndWaitForExtra:request
                                                    extraPrefix:@"telegraphica-map-thumbnail"
                                                        timeout:MIN(timeout, 8.0)
                                                      errorCode:570
                                                          error:&requestError];
    if (!file && requestError) {
        NSDictionary *legacyLocation = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"location", @"@type",
                                        [NSNumber numberWithDouble:latitude], @"latitude",
                                        [NSNumber numberWithDouble:longitude], @"longitude",
                                        nil];
        [request setObject:legacyLocation forKey:@"location"];
        requestError = nil;
        file = [self sendTDLibRequestAndWaitForExtra:request
                                         extraPrefix:@"telegraphica-map-thumbnail-legacy"
                                             timeout:MIN(timeout, 8.0)
                                           errorCode:570
                                               error:&requestError];
    }
    if (![file isKindOfClass:[NSDictionary class]] ||
        ![[file objectForKey:@"@type"] isEqualToString:@"file"]) {
        if (error) {
            *error = requestError ? requestError :
                [self errorWithDescription:@"Telegram did not return a map image." code:570];
        }
        return nil;
    }
    NSDictionary *local = [[file objectForKey:@"local"] isKindOfClass:[NSDictionary class]]
        ? [file objectForKey:@"local"] : nil;
    NSString *path = [[local objectForKey:@"path"] isKindOfClass:[NSString class]]
        ? [local objectForKey:@"path"] : nil;
    if ([[local objectForKey:@"is_downloading_completed"] boolValue] && [path length] > 0) {
        return path;
    }
    NSNumber *fileID = [[file objectForKey:@"id"] respondsToSelector:@selector(integerValue)]
        ? [NSNumber numberWithInteger:[[file objectForKey:@"id"] integerValue]] : nil;
    if (!fileID) {
        if (error) {
            *error = [self errorWithDescription:@"Telegram map image has no file identifier." code:570];
        }
        return nil;
    }
    return [self downloadedLocalPathForFileID:fileID timeout:MAX(2.0, timeout - 2.0) error:error];
}

@end
