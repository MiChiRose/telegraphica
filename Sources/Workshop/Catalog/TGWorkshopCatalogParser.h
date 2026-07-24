#import <Foundation/Foundation.h>

@class TGWorkshopCatalog;

@interface TGWorkshopCatalogParser : NSObject {
@private
    NSDictionary *_certificatePathsByKeyIdentifier;
    BOOL _allowsUnsignedDevelopmentCatalogs;
}

- (id)initWithCertificatePathsByKeyIdentifier:(NSDictionary *)certificatePaths;
@property(nonatomic, assign) BOOL allowsUnsignedDevelopmentCatalogs;
- (TGWorkshopCatalog *)catalogFromEnvelopeData:(NSData *)data error:(NSError **)error;

@end
