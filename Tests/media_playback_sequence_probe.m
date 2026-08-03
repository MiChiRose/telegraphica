#import <Foundation/Foundation.h>
#import "TGMediaPlaybackSequence.h"
#import "TGMessageItem.h"
#include <stdio.h>

static TGMessageItem *TGSequenceItem(NSInteger chatID,
                                     NSInteger messageID,
                                     NSString *contentType,
                                     NSString *mimeType) {
    TGMessageItem *item = [[[TGMessageItem alloc]
        initWithChatID:[NSNumber numberWithInteger:chatID]
             messageID:[NSNumber numberWithInteger:messageID]
                  date:[NSNumber numberWithInteger:messageID]
              outgoing:NO
               preview:contentType] autorelease];
    [item setContentType:contentType];
    [item setMediaMimeType:mimeType];
    return item;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGMessageItem *completed = TGSequenceItem(1, 10, @"messageVoiceNote", @"audio/ogg");
    TGMessageItem *video = TGSequenceItem(1, 11, @"messageVideo", @"video/mp4");
    TGMessageItem *otherChat = TGSequenceItem(2, 12, @"messageVoiceNote", @"audio/ogg");
    TGMessageItem *nextAudio = TGSequenceItem(1, 13, @"messageAudio", @"audio/mpeg");
    NSArray *items = [NSArray arrayWithObjects:completed, video, otherChat, nextAudio, nil];

    if (TGNextSequentialAudioMessageItem(items, completed) != nextAudio) {
        fprintf(stderr, "sequence did not skip video and another chat\n");
        [pool drain];
        return 2;
    }
    TGMessageItem *equivalentCompleted = TGSequenceItem(1, 10, @"messageVoiceNote", @"audio/ogg");
    if (TGNextSequentialAudioMessageItem(items, equivalentCompleted) != nextAudio) {
        fprintf(stderr, "sequence did not recover source by identifiers\n");
        [pool drain];
        return 3;
    }
    if (TGNextSequentialAudioMessageItem(items, nextAudio) != nil) {
        fprintf(stderr, "sequence should end after the last audio item\n");
        [pool drain];
        return 4;
    }
    fprintf(stdout, "Media playback sequence probe passed.\n");
    [pool drain];
    return 0;
}
