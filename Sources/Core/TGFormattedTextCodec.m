#import "TGFormattedTextCodec.h"

static BOOL TGIsHighSurrogate(unichar value) {
    return value >= 0xD800 && value <= 0xDBFF;
}

static BOOL TGIsLowSurrogate(unichar value) {
    return value >= 0xDC00 && value <= 0xDFFF;
}

static NSUInteger TGSafeUTF16BoundaryAtOrBefore(NSString *text, NSUInteger boundary) {
    NSUInteger length = [text length];
    boundary = MIN(boundary, length);
    if (boundary > 0 && boundary < length &&
        TGIsHighSurrogate([text characterAtIndex:boundary - 1]) &&
        TGIsLowSurrogate([text characterAtIndex:boundary])) {
        boundary--;
    }
    if (boundary > 0 && boundary < length) {
        NSRange sequence = [text rangeOfComposedCharacterSequenceAtIndex:boundary - 1];
        if (NSMaxRange(sequence) > boundary) {
            boundary = sequence.location;
        }
    }
    return boundary;
}

static BOOL TGEntityRangeFromObject(NSDictionary *entity, NSString *text, NSRange *range) {
    id offsetObject = [entity objectForKey:@"offset"];
    id lengthObject = [entity objectForKey:@"length"];
    NSDictionary *type = [[entity objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [entity objectForKey:@"type"] : nil;
    NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [type objectForKey:@"@type"] : nil;
    if (![offsetObject respondsToSelector:@selector(longLongValue)] ||
        ![lengthObject respondsToSelector:@selector(longLongValue)] ||
        ![typeName hasPrefix:@"textEntityType"] || ![text isKindOfClass:[NSString class]]) {
        return NO;
    }

    long long offset = [offsetObject longLongValue];
    long long length = [lengthObject longLongValue];
    if (offset < 0 || length <= 0 || offset > (long long)[text length] ||
        length > (long long)[text length] - offset) {
        return NO;
    }
    NSUInteger start = (NSUInteger)offset;
    NSUInteger end = start + (NSUInteger)length;
    if (TGSafeUTF16BoundaryAtOrBefore(text, start) != start ||
        TGSafeUTF16BoundaryAtOrBefore(text, end) != end) {
        return NO;
    }
    if (range) {
        *range = NSMakeRange(start, (NSUInteger)length);
    }
    return YES;
}

static NSComparisonResult TGCompareTextEntities(id leftObject, id rightObject, void *context) {
    (void)context;
    NSDictionary *left = [leftObject isKindOfClass:[NSDictionary class]] ? leftObject : nil;
    NSDictionary *right = [rightObject isKindOfClass:[NSDictionary class]] ? rightObject : nil;
    NSInteger leftOffset = [[left objectForKey:@"offset"] integerValue];
    NSInteger rightOffset = [[right objectForKey:@"offset"] integerValue];
    if (leftOffset < rightOffset) {
        return NSOrderedAscending;
    }
    if (leftOffset > rightOffset) {
        return NSOrderedDescending;
    }
    NSInteger leftLength = [[left objectForKey:@"length"] integerValue];
    NSInteger rightLength = [[right objectForKey:@"length"] integerValue];
    if (leftLength > rightLength) {
        return NSOrderedAscending;
    }
    if (leftLength < rightLength) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

NSArray *TGValidatedTDLibTextEntities(NSArray *entities, NSString *text) {
    if (![entities isKindOfClass:[NSArray class]] || ![text isKindOfClass:[NSString class]] || [text length] == 0) {
        return [NSArray array];
    }
    NSMutableArray *validated = [NSMutableArray array];
    id object = nil;
    for (object in entities) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSRange range = NSMakeRange(0, 0);
        if (!TGEntityRangeFromObject((NSDictionary *)object, text, &range)) {
            continue;
        }
        NSMutableDictionary *entity = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)object];
        [entity setObject:[NSNumber numberWithUnsignedInteger:range.location] forKey:@"offset"];
        [entity setObject:[NSNumber numberWithUnsignedInteger:range.length] forKey:@"length"];
        [validated addObject:entity];
    }
    [validated sortUsingFunction:TGCompareTextEntities context:NULL];
    return validated;
}

NSArray *TGRebasedTDLibTextEntities(NSString *originalText,
                                   NSArray *originalEntities,
                                   NSString *editedText) {
    if (![originalText isKindOfClass:[NSString class]] || ![editedText isKindOfClass:[NSString class]]) {
        return [NSArray array];
    }
    NSArray *validated = TGValidatedTDLibTextEntities(originalEntities, originalText);
    if ([validated count] == 0) {
        return [NSArray array];
    }
    if ([originalText isEqualToString:editedText]) {
        return validated;
    }

    NSUInteger oldLength = [originalText length];
    NSUInteger newLength = [editedText length];
    NSUInteger prefix = 0;
    NSUInteger sharedLimit = MIN(oldLength, newLength);
    while (prefix < sharedLimit && [originalText characterAtIndex:prefix] == [editedText characterAtIndex:prefix]) {
        prefix++;
    }
    prefix = MIN(TGSafeUTF16BoundaryAtOrBefore(originalText, prefix),
                 TGSafeUTF16BoundaryAtOrBefore(editedText, prefix));

    NSUInteger suffix = 0;
    while (suffix < oldLength - prefix && suffix < newLength - prefix &&
           [originalText characterAtIndex:oldLength - suffix - 1] ==
           [editedText characterAtIndex:newLength - suffix - 1]) {
        suffix++;
    }
    NSUInteger oldChangeEnd = TGSafeUTF16BoundaryAtOrBefore(originalText, oldLength - suffix);
    NSUInteger newChangeEnd = TGSafeUTF16BoundaryAtOrBefore(editedText, newLength - suffix);
    long long delta = (long long)newChangeEnd - (long long)oldChangeEnd;

    NSMutableArray *rebased = [NSMutableArray array];
    NSDictionary *entity = nil;
    for (entity in validated) {
        NSUInteger start = [[entity objectForKey:@"offset"] unsignedIntegerValue];
        NSUInteger end = start + [[entity objectForKey:@"length"] unsignedIntegerValue];
        long long newStart = (long long)start;
        long long newEnd = (long long)end;
        if (end <= prefix) {
            /* Unchanged prefix. */
        } else if (start >= oldChangeEnd) {
            newStart += delta;
            newEnd += delta;
        } else if (start < prefix && end > oldChangeEnd) {
            newEnd += delta;
        } else {
            continue;
        }
        if (newStart < 0 || newEnd <= newStart || newEnd > (long long)newLength) {
            continue;
        }
        NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:entity];
        [updated setObject:[NSNumber numberWithLongLong:newStart] forKey:@"offset"];
        [updated setObject:[NSNumber numberWithLongLong:(newEnd - newStart)] forKey:@"length"];
        [rebased addObject:updated];
    }
    return TGValidatedTDLibTextEntities(rebased, editedText);
}

NSDictionary *TGTDLibFormattedTextObject(NSString *text, NSArray *entities) {
    NSString *safeText = [text isKindOfClass:[NSString class]] ? text : @"";
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"formattedText", @"@type",
            safeText, @"text",
            TGValidatedTDLibTextEntities(entities, safeText), @"entities",
            nil];
}

