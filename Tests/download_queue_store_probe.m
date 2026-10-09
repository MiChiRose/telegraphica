#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#import "../Sources/Services/TGDownloadQueueStore.h"

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Download queue assertion failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDictionary *active = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"download-1", @"identifier",
                            @"movie.mp4", @"file_name",
                            @"downloading", @"state",
                            [NSNumber numberWithInt:42], @"file_id",
                            [NSNumber numberWithLongLong:5LL * 1024LL * 1024LL * 1024LL], @"downloaded_bytes",
                            [NSNumber numberWithLongLong:6LL * 1024LL * 1024LL * 1024LL], @"total_bytes",
                            [NSNumber numberWithBool:YES], @"reconnecting",
                            [NSDate dateWithTimeIntervalSince1970:10], @"created_at",
                            nil];
    NSDictionary *invalid = [NSDictionary dictionaryWithObject:@"queued" forKey:@"state"];
    NSArray *restored = TGDownloadQueueNormalizedRecords([NSArray arrayWithObjects:active, invalid, nil]);
    TGAssert([restored count] == 1, @"invalid records must be discarded");
    TGAssert([[[restored objectAtIndex:0] objectForKey:@"state"] isEqualToString:@"interrupted"],
             @"active records must become resumable after restart");
    TGAssert([[[restored objectAtIndex:0] objectForKey:@"file_id"] integerValue] == 42,
             @"TDLib file identifier must survive restoration");

    TGAssert([[[restored objectAtIndex:0] objectForKey:@"downloaded_bytes"] longLongValue] == 5LL * 1024LL * 1024LL * 1024LL,
             @"large downloaded byte progress must survive restore without int32 overflow");
    TGAssert([[[restored objectAtIndex:0] objectForKey:@"reconnecting"] boolValue], @"reconnect progress must survive restore");
    NSArray *serialized = TGDownloadQueueSerializableRecords(restored);
    TGAssert([serialized count] == 1, @"restored queue must remain serializable");
    TGAssert([[[serialized objectAtIndex:0] objectForKey:@"file_name"] isEqualToString:@"movie.mp4"],
             @"safe display metadata must survive serialization");
    TGAssert([NSPropertyListSerialization propertyList:serialized isValidForFormat:NSPropertyListBinaryFormat_v1_0],
             @"persisted queue must be a property list");
    fprintf(stdout, "Download queue store probe passed.\n");
    [pool drain];
    return 0;
}
