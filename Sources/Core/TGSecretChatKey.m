#import "TGSecretChatKey.h"

@implementation TGSecretChatKey

+ (NSArray *)colorIndexesForKeyHashData:(NSData *)keyHashData {
    if (![keyHashData isKindOfClass:[NSData class]] || [keyHashData length] < 36) {
        return [NSArray array];
    }
    const unsigned char *bytes = (const unsigned char *)[keyHashData bytes];
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:144];
    NSUInteger byteIndex = 0;
    for (byteIndex = 0; byteIndex < 36; byteIndex++) {
        NSUInteger pairIndex = 0;
        for (pairIndex = 0; pairIndex < 4; pairIndex++) {
            [indexes addObject:[NSNumber numberWithUnsignedInteger:((bytes[byteIndex] >> (pairIndex * 2)) & 0x03)]];
        }
    }
    return indexes;
}

+ (NSString *)fingerprintForKeyHashData:(NSData *)keyHashData {
    if (![keyHashData isKindOfClass:[NSData class]] || [keyHashData length] < 32) {
        return @"";
    }
    const unsigned char *bytes = (const unsigned char *)[keyHashData bytes];
    NSMutableArray *groups = [NSMutableArray arrayWithCapacity:8];
    NSUInteger groupIndex = 0;
    for (groupIndex = 0; groupIndex < 8; groupIndex++) {
        NSMutableString *group = [NSMutableString stringWithCapacity:8];
        NSUInteger byteIndex = 0;
        for (byteIndex = 0; byteIndex < 4; byteIndex++) {
            [group appendFormat:@"%02X", bytes[(groupIndex * 4) + byteIndex]];
        }
        [groups addObject:group];
    }
    return [groups componentsJoinedByString:@" "];
}

@end
