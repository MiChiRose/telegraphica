#import "TGOutgoingMessageTextChunker.h"

NSUInteger const TGOutgoingTextMessageMaximumLength = 4060;

NSArray *TGOutgoingTextMessageChunks(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || [text length] == 0) {
        return [NSArray array];
    }

    NSMutableArray *chunks = [NSMutableArray array];
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSUInteger length = [text length];
    NSUInteger offset = 0;
    while (offset < length) {
        NSUInteger remaining = length - offset;
        NSUInteger chunkLength = MIN(TGOutgoingTextMessageMaximumLength, remaining);
        NSUInteger end = offset + chunkLength;
        if (end < length) {
            NSRange boundaryRange = [text rangeOfComposedCharacterSequenceAtIndex:end];
            if (boundaryRange.location < end && boundaryRange.location > offset) {
                end = boundaryRange.location;
            }
        }

        NSRange chunkRange = NSMakeRange(offset, end - offset);
        if (NSMaxRange(chunkRange) < length && chunkRange.length > 80) {
            NSUInteger minimumSplit = offset + MIN((NSUInteger)80, chunkRange.length - 1);
            NSUInteger scanIndex = NSMaxRange(chunkRange);
            while (scanIndex > minimumSplit) {
                scanIndex--;
                unichar character = [text characterAtIndex:scanIndex];
                if ([whitespaceSet characterIsMember:character]) {
                    NSRange composedWhitespace = [text rangeOfComposedCharacterSequenceAtIndex:scanIndex];
                    if (NSMaxRange(composedWhitespace) > offset && NSMaxRange(composedWhitespace) <= NSMaxRange(chunkRange)) {
                        chunkRange.length = NSMaxRange(composedWhitespace) - offset;
                    }
                    break;
                }
            }
        }

        if (chunkRange.length == 0) {
            chunkRange.length = MIN(TGOutgoingTextMessageMaximumLength, length - offset);
        }
        [chunks addObject:[text substringWithRange:chunkRange]];
        offset = NSMaxRange(chunkRange);
    }
    return chunks;
}
