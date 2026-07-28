#import "TGLocationSearchService.h"

#import <MapKit/MapKit.h>

@interface TGLocationSearchOperation : NSObject
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy) TGLocationSearchCompletion completion;
- (void)cancel;
@end

@implementation TGLocationSearchOperation

@synthesize cancelled = _cancelled;
@synthesize completion = _completion;

- (void)dealloc {
    [_completion release];
    [super dealloc];
}

- (void)cancel {
    self.cancelled = YES;
    self.completion = nil;
}

@end

@interface TGLocationSearchService ()
@property (nonatomic, retain) MKLocalSearch *activeSearch;
@property (nonatomic, retain) TGLocationSearchOperation *activeOperation;
@end

@implementation TGLocationSearchService

@synthesize activeSearch = _activeSearch;
@synthesize activeOperation = _activeOperation;

- (void)dealloc {
    [self cancel];
    [super dealloc];
}

- (BOOL)isAvailable {
    return (NSClassFromString(@"MKLocalSearchRequest") != Nil &&
            NSClassFromString(@"MKLocalSearch") != Nil);
}

- (NSError *)unavailableError {
    return [NSError errorWithDomain:@"TelegraphicaLocationSearch"
                               code:1
                           userInfo:[NSDictionary dictionaryWithObject:@"Location search is unavailable on this system."
                                                                forKey:NSLocalizedDescriptionKey]];
}

- (void)searchForQuery:(NSString *)query
        centerLatitude:(double)latitude
       centerLongitude:(double)longitude
            completion:(TGLocationSearchCompletion)completion {
    [self cancel];
    if (![self isAvailable] || [query length] == 0) {
        if (completion) {
            completion([NSArray array], [self unavailableError]);
        }
        return;
    }

    MKLocalSearchRequest *request = [[[NSClassFromString(@"MKLocalSearchRequest") alloc] init] autorelease];
    [request setNaturalLanguageQuery:query];
    [request setRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(latitude, longitude),
                                               MKCoordinateSpanMake(0.75, 0.75))];

    MKLocalSearch *search = [[[NSClassFromString(@"MKLocalSearch") alloc] initWithRequest:request] autorelease];
    TGLocationSearchOperation *operation = [[[TGLocationSearchOperation alloc] init] autorelease];
    operation.completion = completion;
    self.activeSearch = search;
    self.activeOperation = operation;

    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if ([operation isCancelled]) {
            return;
        }
        NSMutableArray *results = [NSMutableArray array];
        NSArray *mapItems = [[response mapItems] isKindOfClass:[NSArray class]]
            ? [response mapItems] : [NSArray array];
        NSUInteger index = 0;
        for (index = 0; index < [mapItems count]; index++) {
            MKMapItem *item = [mapItems objectAtIndex:index];
            CLLocation *location = [[item placemark] location];
            if (!location || !CLLocationCoordinate2DIsValid([location coordinate])) {
                continue;
            }
            NSString *title = [item name];
            NSString *detail = [[item placemark] title];
            CLLocationCoordinate2D coordinate = [location coordinate];
            [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithDouble:coordinate.latitude], @"latitude",
                                [NSNumber numberWithDouble:coordinate.longitude], @"longitude",
                                ([title length] > 0 ? title : @""), @"title",
                                ([detail length] > 0 ? detail : @""), @"detail",
                                nil]];
        }
        TGLocationSearchCompletion callback = [operation.completion copy];
        [operation cancel];
        if (callback) {
            callback(results, error);
            [callback release];
        }
    }];
}

- (void)cancel {
    [self.activeOperation cancel];
    [self.activeSearch cancel];
    self.activeOperation = nil;
    self.activeSearch = nil;
}

@end
