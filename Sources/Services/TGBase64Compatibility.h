#import <Foundation/Foundation.h>

#ifndef TGBase64Compatibility_h
#define TGBase64Compatibility_h

static inline NSString *TGBase64EncodedString(NSData *data) {
    if (![data isKindOfClass:[NSData class]]) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [data base64Encoding];
#pragma clang diagnostic pop
}

static inline NSData *TGDataFromBase64String(NSString *string) {
    if (![string isKindOfClass:[NSString class]] || [string length] == 0) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[[NSData alloc] initWithBase64Encoding:string] autorelease];
#pragma clang diagnostic pop
}

#endif
