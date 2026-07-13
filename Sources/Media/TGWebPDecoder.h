#import <Cocoa/Cocoa.h>

BOOL TGDataHasWebPHeader(NSData *data);
NSImage *TGWebPImageFromData(NSData *data);
NSImage *TGWebPImageFromFile(NSString *path);
