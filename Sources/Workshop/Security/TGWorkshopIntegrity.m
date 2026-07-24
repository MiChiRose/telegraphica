#import "TGWorkshopIntegrity.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <dlfcn.h>

typedef OSStatus (*TGWorkshopSecKeyRawVerifyFunction)(SecKeyRef key,
                                                      uint32_t padding,
                                                      const uint8_t *signedData,
                                                      size_t signedDataLength,
                                                      const uint8_t *signature,
                                                      size_t signatureLength);

static NSError *TGWorkshopIntegrityError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSString *TGWorkshopHexDigest(const unsigned char *digest, NSUInteger length) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:length * 2];
    NSUInteger index = 0;
    for (index = 0; index < length; index++) {
        [hex appendFormat:@"%02x", digest[index]];
    }
    return hex;
}

@implementation TGWorkshopIntegrity

+ (NSString *)SHA256ForFileAtPath:(NSString *)path error:(NSError **)error {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    if (!stream) {
        if (error) *error = TGWorkshopIntegrityError(300, @"Could not open Workshop file for hashing.");
        return nil;
    }

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    [stream open];
    uint8_t buffer[64 * 1024];
    NSInteger readLength = 0;
    while ((readLength = [stream read:buffer maxLength:sizeof(buffer)]) > 0) {
        CC_SHA256_Update(&context, buffer, (CC_LONG)readLength);
    }
    NSError *streamError = [stream streamError];
    [stream close];
    if (readLength < 0 || streamError) {
        if (error) *error = streamError ? streamError : TGWorkshopIntegrityError(301, @"Could not read Workshop file for hashing.");
        return nil;
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    return TGWorkshopHexDigest(digest, CC_SHA256_DIGEST_LENGTH);
}

+ (BOOL)fileAtPath:(NSString *)path matchesSHA256:(NSString *)expectedSHA256 error:(NSError **)error {
    NSString *actual = [self SHA256ForFileAtPath:path error:error];
    if (!actual) {
        return NO;
    }
    BOOL matches = ([actual caseInsensitiveCompare:expectedSHA256] == NSOrderedSame);
    if (!matches && error) {
        *error = TGWorkshopIntegrityError(302, @"Workshop package checksum does not match the signed catalog.");
    }
    return matches;
}

+ (BOOL)verifySignature:(NSData *)signature
              overData:(NSData *)data
                domain:(NSString *)domain
 certificateDERAtPath:(NSString *)certificatePath
                 error:(NSError **)error {
    NSData *certificateData = [NSData dataWithContentsOfFile:certificatePath];
    if ([certificateData length] == 0 || [signature length] == 0 || !data || [domain length] == 0) {
        if (error) *error = TGWorkshopIntegrityError(303, @"Workshop signature input is incomplete.");
        return NO;
    }

    SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (CFDataRef)certificateData);
    if (!certificate) {
        if (error) *error = TGWorkshopIntegrityError(304, @"Workshop signing certificate is invalid.");
        return NO;
    }

    SecPolicyRef policy = SecPolicyCreateBasicX509();
    SecTrustRef trust = NULL;
    OSStatus trustStatus = SecTrustCreateWithCertificates(certificate, policy, &trust);
    SecKeyRef publicKey = NULL;
    if (trustStatus == errSecSuccess && trust) {
        publicKey = SecTrustCopyPublicKey(trust);
    }

    BOOL verified = NO;
    if (publicKey) {
        CC_SHA256_CTX context;
        CC_SHA256_Init(&context);
        NSData *domainData = [domain dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&context, [domainData bytes], (CC_LONG)[domainData length]);
        const unsigned char separator = 0;
        CC_SHA256_Update(&context, &separator, 1);
        CC_SHA256_Update(&context, [data bytes], (CC_LONG)[data length]);
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(digest, &context);

        static const unsigned char SHA256DigestInfoPrefix[] = {
            0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
            0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
        };
        NSMutableData *digestInfo = [NSMutableData dataWithBytes:SHA256DigestInfoPrefix
                                                          length:sizeof(SHA256DigestInfoPrefix)];
        [digestInfo appendBytes:digest length:CC_SHA256_DIGEST_LENGTH];

        TGWorkshopSecKeyRawVerifyFunction rawVerify = (TGWorkshopSecKeyRawVerifyFunction)dlsym(RTLD_DEFAULT, "SecKeyRawVerify");
        if (rawVerify) {
            OSStatus status = rawVerify(publicKey,
                                        (uint32_t)kSecPaddingPKCS1,
                                        [digestInfo bytes],
                                        [digestInfo length],
                                        [signature bytes],
                                        [signature length]);
            verified = (status == errSecSuccess);
            if (!verified && error) {
                *error = TGWorkshopIntegrityError(305, @"Workshop signature verification failed.");
            }
        } else if (error) {
            *error = TGWorkshopIntegrityError(307, @"This system does not provide the required Workshop signature verifier.");
        }
    } else if (error) {
        *error = TGWorkshopIntegrityError(306, @"Could not read the Workshop public signing key.");
    }

    if (publicKey) CFRelease(publicKey);
    if (trust) CFRelease(trust);
    if (policy) CFRelease(policy);
    CFRelease(certificate);
    return verified;
}

@end
