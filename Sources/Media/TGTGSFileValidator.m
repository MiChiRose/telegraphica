#import "TGTGSFileValidator.h"
#import <zlib.h>
#include <math.h>
#include <string.h>

static const NSUInteger TGTGSMaximumCompressedBytes = 64 * 1024;
static const NSUInteger TGTGSMaximumInflatedBytes = 1024 * 1024;
static const NSUInteger TGTGSMaximumFrameCount = 360;
static const CGFloat TGTGSMaximumFrameRate = 60.0;
static const CGFloat TGTGSMaximumDuration = 6.1;

static NSData *TGTGSInflatedData(NSData *compressedData) {
    if (![compressedData isKindOfClass:[NSData class]] ||
        [compressedData length] < 2 ||
        [compressedData length] > TGTGSMaximumCompressedBytes) {
        return nil;
    }

    const unsigned char *bytes = (const unsigned char *)[compressedData bytes];
    if (bytes[0] != 0x1f || bytes[1] != 0x8b) {
        return nil;
    }

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    stream.next_in = (Bytef *)[compressedData bytes];
    stream.avail_in = (uInt)[compressedData length];
    if (inflateInit2(&stream, 16 + MAX_WBITS) != Z_OK) {
        return nil;
    }

    NSMutableData *output = [NSMutableData dataWithLength:64 * 1024];
    int result = Z_OK;
    while (result == Z_OK) {
        if (stream.total_out >= [output length]) {
            NSUInteger nextLength = [output length] * 2;
            if (nextLength > TGTGSMaximumInflatedBytes) {
                inflateEnd(&stream);
                return nil;
            }
            [output increaseLengthBy:[output length]];
        }
        stream.next_out = (Bytef *)[output mutableBytes] + stream.total_out;
        stream.avail_out = (uInt)([output length] - stream.total_out);
        result = inflate(&stream, Z_NO_FLUSH);
    }
    if (result != Z_STREAM_END || stream.total_out == 0 || stream.total_out > TGTGSMaximumInflatedBytes) {
        inflateEnd(&stream);
        return nil;
    }
    NSUInteger finalLength = (NSUInteger)stream.total_out;
    inflateEnd(&stream);
    [output setLength:finalLength];
    return output;
}

static BOOL TGTGSHasExternalImageAssets(NSDictionary *root) {
    id assetsObject = [root objectForKey:@"assets"];
    if (![assetsObject isKindOfClass:[NSArray class]]) {
        return NO;
    }
    for (id candidate in (NSArray *)assetsObject) {
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *asset = (NSDictionary *)candidate;
        if ([asset objectForKey:@"p"] || [asset objectForKey:@"u"] || [asset objectForKey:@"e"]) {
            return YES;
        }
    }
    return NO;
}

NSData *TGTGSValidatedJSONDataAtPath(NSString *path,
                                     NSUInteger *frameCountOut,
                                     CGFloat *frameRateOut) {
    NSData *jsonData = TGTGSInflatedData([NSData dataWithContentsOfFile:path]);
    if (![jsonData isKindOfClass:[NSData class]] ||
        [jsonData length] == 0 ||
        [jsonData length] > TGTGSMaximumInflatedBytes) {
        return nil;
    }

    NSError *jsonError = nil;
    id rootObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
    if (jsonError || ![rootObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *root = (NSDictionary *)rootObject;
    id widthObject = [root objectForKey:@"w"];
    id heightObject = [root objectForKey:@"h"];
    id frameRateObject = [root objectForKey:@"fr"];
    id inPointObject = [root objectForKey:@"ip"];
    id outPointObject = [root objectForKey:@"op"];
    if (![widthObject respondsToSelector:@selector(doubleValue)] ||
        ![heightObject respondsToSelector:@selector(doubleValue)] ||
        ![frameRateObject respondsToSelector:@selector(doubleValue)] ||
        ![inPointObject respondsToSelector:@selector(doubleValue)] ||
        ![outPointObject respondsToSelector:@selector(doubleValue)]) {
        return nil;
    }

    double width = [widthObject doubleValue];
    double height = [heightObject doubleValue];
    double frameRate = [frameRateObject doubleValue];
    double inPoint = [inPointObject doubleValue];
    double outPoint = [outPointObject doubleValue];
    double frameCount = ceil(outPoint - inPoint);
    double duration = frameCount / frameRate;
    if (!isfinite(width) || !isfinite(height) || !isfinite(frameRate) ||
        !isfinite(inPoint) || !isfinite(outPoint) || !isfinite(duration) ||
        width <= 0.0 || width > 512.0 || height <= 0.0 || height > 512.0 ||
        frameRate <= 0.0 || frameRate > TGTGSMaximumFrameRate ||
        frameCount <= 0.0 || frameCount > (double)TGTGSMaximumFrameCount ||
        duration <= 0.0 || duration > TGTGSMaximumDuration ||
        TGTGSHasExternalImageAssets(root)) {
        return nil;
    }

    if (frameCountOut) {
        *frameCountOut = (NSUInteger)frameCount;
    }
    if (frameRateOut) {
        *frameRateOut = (CGFloat)frameRate;
    }
    return jsonData;
}
