#import <Foundation/Foundation.h>
#import "../Sources/Core/TGAddedReactionsParser.h"

static void TGAssert(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "Added reactions probe failed: %s\n", message);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *data = [NSData dataWithContentsOfFile:@"Tests/Fixtures/added_reactions_page.json"];
    TGAssert(data != nil, "fixture must be readable");
    NSError *jsonError = nil;
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    TGAssert(response != nil && jsonError == nil, "fixture must be valid JSON");
    NSDictionary *page = TGAddedReactionsPageFromTDLibResponse(response);
    NSArray *items = [page objectForKey:TGAddedReactionsItemsKey];
    TGAssert([items count] == 2U, "paid and malformed reactions must be excluded");
    TGAssert([[[items objectAtIndex:0] objectForKey:TGAddedReactionEmojiKey] isEqualToString:@"🔥"],
             "standard emoji must be preserved");
    TGAssert([[[items objectAtIndex:1] objectForKey:TGAddedReactionCustomEmojiIDKey] longLongValue] == 202,
             "custom emoji identifier must be preserved");
    TGAssert([[[page objectForKey:TGAddedReactionsNextOffsetKey] description] isEqualToString:@"page-2"],
             "pagination offset must be preserved");
    NSDictionary *wrongType = [NSDictionary dictionaryWithObject:@"error" forKey:@"@type"];
    TGAssert(TGAddedReactionsPageFromTDLibResponse(wrongType) == nil,
             "unexpected response types must be rejected");
    fprintf(stdout, "Added reactions probe passed.\n");
    [pool drain];
    return 0;
}
