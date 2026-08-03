#import <Foundation/Foundation.h>
#import "TGChatFolderSupport.h"

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "chat folder support probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGAssert(argc == 2, @"fixture path is required");
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
    TGAssert(data != nil, @"fixture must load");
    NSError *error = nil;
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    TGAssert(fixture != nil && error == nil, @"fixture must parse");

    NSArray *links = TGChatFolderNormalizeInviteLinks([fixture objectForKey:@"invite_links"]);
    TGAssert([links count] == 1, @"invalid links must be omitted");
    TGAssert([[[links objectAtIndex:0] objectForKey:@"chat_ids"] count] == 2, @"chat identifiers must be normalized");
    TGAssert([[[[links objectAtIndex:0] objectForKey:@"chat_ids"] objectAtIndex:1] longLongValue] == 202, @"string identifiers must be numeric");

    NSArray *recommended = TGChatFolderNormalizeRecommendedFolders([fixture objectForKey:@"recommended"]);
    TGAssert([recommended count] == 1, @"recommended folder must normalize");
    NSDictionary *definition = [[recommended objectAtIndex:0] objectForKey:@"definition"];
    TGAssert([[definition objectForKey:@"title"] isEqualToString:@"Unread"], @"formatted folder name must parse");
    TGAssert([[definition objectForKey:@"exclude_read"] boolValue], @"folder rules must survive parsing");
    TGAssert([[[definition objectForKey:@"included_chat_ids"] objectAtIndex:0] longLongValue] == 404, @"folder chat IDs must survive parsing");

    TGAssert([TGChatFolderOptionInteger([fixture objectForKey:@"limit"]) integerValue] == 10, @"integer limit must parse");
    TGAssert(TGChatFolderOptionInteger([fixture objectForKey:@"malformed_limit"]) == nil, @"non-integer limit must be rejected");
    TGAssert([[TGChatFolderSafeIdentifierArray(@[@1, @"2", [NSNull null]]) objectAtIndex:1] integerValue] == 2,
             @"safe identifier helper must normalize values");

    fprintf(stdout, "chat folder support probe passed\n");
    [pool drain];
    return 0;
}
