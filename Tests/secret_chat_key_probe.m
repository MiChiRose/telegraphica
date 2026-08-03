#import <Foundation/Foundation.h>

#import "TGSecretChatKey.h"

static void TGRequire(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Secret chat key probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    unsigned char bytes[36];
    memset(bytes, 0xE4, sizeof(bytes));
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSArray *indexes = [TGSecretChatKey colorIndexesForKeyHashData:data];
    TGRequire([indexes count] == 144, @"the visual key must contain 12 × 12 color indexes");
    TGRequire([[indexes objectAtIndex:0] integerValue] == 0, @"first low-endian pair must be decoded");
    TGRequire([[indexes objectAtIndex:1] integerValue] == 1, @"second low-endian pair must be decoded");
    TGRequire([[indexes objectAtIndex:2] integerValue] == 2, @"third low-endian pair must be decoded");
    TGRequire([[indexes objectAtIndex:3] integerValue] == 3, @"fourth low-endian pair must be decoded");
    NSString *fingerprint = [TGSecretChatKey fingerprintForKeyHashData:data];
    TGRequire([fingerprint isEqualToString:@"E4E4E4E4 E4E4E4E4 E4E4E4E4 E4E4E4E4 E4E4E4E4 E4E4E4E4 E4E4E4E4 E4E4E4E4"],
              @"fingerprint must expose the first 32 key-hash bytes in stable groups");
    TGRequire([[TGSecretChatKey colorIndexesForKeyHashData:[NSData data]] count] == 0,
              @"short hashes must be rejected");
    TGRequire([[TGSecretChatKey fingerprintForKeyHashData:[NSData data]] length] == 0,
              @"short hashes must not produce fingerprints");
    printf("Secret chat key probe passed.\n");
    [pool drain];
    return 0;
}
