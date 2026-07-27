#import "TGTDLibClient+LocationMessages.h"

#import "TGTDLibClient+MapThumbnail.h"

@implementation TGTDLibClient (LocationMessages)

- (NSDictionary *)locationMediaInfoFromMessageContentObject:(id)contentObject
                                                    timeout:(NSTimeInterval)timeout {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *content = (NSDictionary *)contentObject;
    NSString *contentType = [[content objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [content objectForKey:@"@type"] : @"";
    NSDictionary *location = nil;
    if ([contentType isEqualToString:@"messageLocation"]) {
        location = [[content objectForKey:@"location"] isKindOfClass:[NSDictionary class]]
            ? [content objectForKey:@"location"] : nil;
    } else if ([contentType isEqualToString:@"messageVenue"]) {
        NSDictionary *venue = [[content objectForKey:@"venue"] isKindOfClass:[NSDictionary class]]
            ? [content objectForKey:@"venue"] : nil;
        location = [[venue objectForKey:@"location"] isKindOfClass:[NSDictionary class]]
            ? [venue objectForKey:@"location"] : nil;
    }
    id latitudeObject = [location objectForKey:@"latitude"];
    id longitudeObject = [location objectForKey:@"longitude"];
    if (![latitudeObject respondsToSelector:@selector(doubleValue)] ||
        ![longitudeObject respondsToSelector:@selector(doubleValue)]) {
        return nil;
    }
    double latitude = [latitudeObject doubleValue];
    double longitude = [longitudeObject doubleValue];
    if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        return nil;
    }

    NSError *error = nil;
    NSString *path = [self mapThumbnailPathForLatitude:latitude
                                             longitude:longitude
                                                  zoom:15
                                                 width:520
                                                height:260
                                               timeout:timeout
                                                 error:&error];
    if ([path length] == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            path, @"local_path",
            [NSNumber numberWithInteger:520], @"width",
            [NSNumber numberWithInteger:260], @"height",
            contentType, @"content_type",
            ([contentType isEqualToString:@"messageVenue"] ? @"Place" : @"Location"), @"placeholder",
            [NSNumber numberWithDouble:latitude], @"latitude",
            [NSNumber numberWithDouble:longitude], @"longitude",
            nil];
}

@end
