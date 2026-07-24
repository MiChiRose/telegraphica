#import <Foundation/Foundation.h>

@class TGWorkshopCatalog;
@class TGWorkshopCatalogParser;

typedef void (^TGWorkshopCatalogCompletion)(TGWorkshopCatalog *catalog, BOOL stale, NSError *error);

@interface TGWorkshopCatalogClient : NSObject <NSURLConnectionDataDelegate> {
@private
    TGWorkshopCatalogParser *_parser;
    NSURLConnection *_connection;
    NSMutableData *_responseData;
    NSHTTPURLResponse *_response;
    TGWorkshopCatalogCompletion _completion;
    BOOL _retriedWithoutValidators;
}

- (id)initWithParser:(TGWorkshopCatalogParser *)parser;
- (void)fetchCatalogWithCompletion:(TGWorkshopCatalogCompletion)completion;
- (void)cancel;
- (TGWorkshopCatalog *)cachedOrBundledCatalogAllowingExpired:(BOOL)allowExpired
                                                       stale:(BOOL *)stale
                                                       error:(NSError **)error;

@end
