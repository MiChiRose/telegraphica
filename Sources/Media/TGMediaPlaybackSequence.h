#import <Foundation/Foundation.h>

@class TGMessageItem;

BOOL TGMessageItemCanParticipateInSequentialAudio(TGMessageItem *item);
TGMessageItem *TGNextSequentialAudioMessageItem(NSArray *messageItems,
                                                TGMessageItem *completedItem);
