#import "TGWorkshopCatalogParser.h"
#import "TGWorkshopCatalog.h"
#import "../Security/TGWorkshopIntegrity.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../../Services/TGBase64Compatibility.h"

static NSError *TGWorkshopCatalogParserError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

@implementation TGWorkshopCatalogParser

@synthesize allowsUnsignedDevelopmentCatalogs = _allowsUnsignedDevelopmentCatalogs;

- (id)initWithCertificatePathsByKeyIdentifier:(NSDictionary *)certificatePaths {
    self = [super init];
    if (self) {
        _certificatePathsByKeyIdentifier = [certificatePaths copy];
    }
    return self;
}

- (TGWorkshopCatalog *)catalogFromEnvelopeData:(NSData *)data error:(NSError **)error {
    if ([data length] == 0) {
        if (error) *error = TGWorkshopCatalogParserError(220, @"Workshop catalog is empty.");
        return nil;
    }

    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error) *error = jsonError ? jsonError : TGWorkshopCatalogParserError(221, @"Workshop catalog envelope is not a dictionary.");
        return nil;
    }
    NSDictionary *envelope = object;
    if ([[envelope objectForKey:@"schema_version"] unsignedIntegerValue] != TGWorkshopCatalogSchemaVersion) {
        if (error) *error = TGWorkshopCatalogParserError(222, @"Workshop catalog schema is unsupported.");
        return nil;
    }

    NSString *payloadBase64 = [[envelope objectForKey:@"payload"] isKindOfClass:[NSString class]] ? [envelope objectForKey:@"payload"] : nil;
    NSData *payloadData = TGDataFromBase64String(payloadBase64);
    if ([payloadData length] == 0) {
        if (error) *error = TGWorkshopCatalogParserError(223, @"Workshop catalog payload is missing.");
        return nil;
    }

    BOOL developmentUnsigned = [[envelope objectForKey:@"development_unsigned"] boolValue];
    if (!(developmentUnsigned && _allowsUnsignedDevelopmentCatalogs)) {
        NSString *keyIdentifier = [[envelope objectForKey:@"key_id"] isKindOfClass:[NSString class]] ? [envelope objectForKey:@"key_id"] : nil;
        NSString *algorithm = [[envelope objectForKey:@"algorithm"] isKindOfClass:[NSString class]] ? [envelope objectForKey:@"algorithm"] : nil;
        NSString *signatureBase64 = [[envelope objectForKey:@"catalog_signature"] isKindOfClass:[NSString class]] ? [envelope objectForKey:@"catalog_signature"] : nil;
        NSString *certificatePath = [_certificatePathsByKeyIdentifier objectForKey:keyIdentifier];
        NSData *signature = TGDataFromBase64String(signatureBase64);
        if (![algorithm isEqualToString:@"rsa-pkcs1-sha256"] || [certificatePath length] == 0 || [signature length] == 0) {
            if (error) *error = TGWorkshopCatalogParserError(224, @"Workshop catalog signing key is unknown.");
            return nil;
        }
        if (![TGWorkshopIntegrity verifySignature:signature
                                         overData:payloadData
                                           domain:TGWorkshopCatalogSignatureDomain
                            certificateDERAtPath:certificatePath
                                            error:error]) {
            return nil;
        }
    }

    id payloadObject = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:&jsonError];
    if (![payloadObject isKindOfClass:[NSDictionary class]]) {
        if (error) *error = jsonError ? jsonError : TGWorkshopCatalogParserError(225, @"Workshop catalog payload is malformed.");
        return nil;
    }
    return [[[TGWorkshopCatalog alloc] initWithPayloadDictionary:payloadObject error:error] autorelease];
}

- (void)dealloc {
    [_certificatePathsByKeyIdentifier release];
    [super dealloc];
}

@end
