#import <Cocoa/Cocoa.h>

typedef enum {
    TGAttachmentKindUnsupported = 0,
    TGAttachmentKindPhoto = 1,
    TGAttachmentKindVideo = 2,
    TGAttachmentKindAudio = 3,
    TGAttachmentKindDocument = 4
} TGAttachmentKind;

@interface TGAttachmentDescriptor : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *extension;
@property (nonatomic, copy) NSString *typeLabel;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, assign) TGAttachmentKind kind;
@property (nonatomic, assign) unsigned long long fileSize;
- (BOOL)isSupported;
- (BOOL)isLarge;
- (NSString *)readableSize;
- (NSString *)summary;
+ (TGAttachmentDescriptor *)descriptorForPath:(NSString *)path;
+ (TGAttachmentDescriptor *)firstDescriptorFromPasteboard:(NSPasteboard *)pasteboard;
+ (NSArray *)supportedOpenPanelTypes;
@end
