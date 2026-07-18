#import "TGAttachmentDescriptor.h"
#import "../Services/TGResourcePolicy.h"
#import <ImageIO/ImageIO.h>

@implementation TGAttachmentDescriptor

@synthesize path = _path;
@synthesize fileName = _fileName;
@synthesize extension = _extension;
@synthesize typeLabel = _typeLabel;
@synthesize errorMessage = _errorMessage;
@synthesize kind = _kind;
@synthesize fileSize = _fileSize;
@synthesize pixelWidth = _pixelWidth;
@synthesize pixelHeight = _pixelHeight;

static BOOL TGAttachmentExtensionInSet(NSString *extension, NSArray *set) {
    if ([extension length] == 0) {
        return NO;
    }
    return [set containsObject:[extension lowercaseString]];
}

static void TGAttachmentReadImageDimensions(NSString *path, NSUInteger *width, NSUInteger *height) {
    if (width) {
        *width = 0;
    }
    if (height) {
        *height = 0;
    }
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return;
    }

    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)path,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
    if (!fileURL) {
        return;
    }
    CGImageSourceRef source = CGImageSourceCreateWithURL(fileURL, NULL);
    CFRelease(fileURL);
    if (!source) {
        return;
    }

    NSDictionary *properties = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    if ([properties isKindOfClass:[NSDictionary class]]) {
        id pixelWidth = [properties objectForKey:(NSString *)kCGImagePropertyPixelWidth];
        id pixelHeight = [properties objectForKey:(NSString *)kCGImagePropertyPixelHeight];
        if ([pixelWidth respondsToSelector:@selector(unsignedIntegerValue)] && width) {
            *width = [pixelWidth unsignedIntegerValue];
        }
        if ([pixelHeight respondsToSelector:@selector(unsignedIntegerValue)] && height) {
            *height = [pixelHeight unsignedIntegerValue];
        }
    }
    if (properties) {
        CFRelease(properties);
    }
    CFRelease(source);
}

+ (NSArray *)supportedOpenPanelTypes {
    return [NSArray arrayWithObjects:
            @"jpg", @"jpeg", @"png", @"tif", @"tiff", @"gif", @"webp",
            @"mp4", @"mov", @"m4v", @"webm",
            @"mp3", @"m4a", @"aac", @"wav", @"aiff", @"ogg", @"oga", @"opus",
            @"pdf", @"zip", @"rar", @"7z", @"txt", @"rtf", @"doc", @"docx", @"xls", @"xlsx", @"ppt", @"pptx",
            nil];
}

+ (TGAttachmentDescriptor *)descriptorForPath:(NSString *)path {
    TGAttachmentDescriptor *descriptor = [[[TGAttachmentDescriptor alloc] init] autorelease];
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        descriptor.errorMessage = @"File path is missing.";
        return descriptor;
    }

    NSString *standardPath = [path stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardPath isDirectory:&isDirectory] || isDirectory) {
        descriptor.path = standardPath;
        descriptor.errorMessage = isDirectory ? @"Folders are not supported yet." : @"File does not exist.";
        return descriptor;
    }

    descriptor.path = standardPath;
    descriptor.fileName = [standardPath lastPathComponent];
    descriptor.extension = [[standardPath pathExtension] lowercaseString];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:standardPath error:NULL];
    id sizeObject = [attributes objectForKey:NSFileSize];
    if ([sizeObject respondsToSelector:@selector(unsignedLongLongValue)]) {
        descriptor.fileSize = [sizeObject unsignedLongLongValue];
    }

    NSArray *photoExtensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"tif", @"tiff", @"gif", @"webp", nil];
    NSArray *videoExtensions = [NSArray arrayWithObjects:@"mp4", @"mov", @"m4v", @"webm", nil];
    NSArray *audioExtensions = [NSArray arrayWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"aiff", @"ogg", @"oga", @"opus", nil];
    NSArray *documentExtensions = [NSArray arrayWithObjects:@"pdf", @"zip", @"rar", @"7z", @"txt", @"rtf", @"doc", @"docx", @"xls", @"xlsx", @"ppt", @"pptx", nil];

    if (TGAttachmentExtensionInSet(descriptor.extension, photoExtensions)) {
        descriptor.kind = TGAttachmentKindPhoto;
        descriptor.typeLabel = @"Photo";
        NSUInteger bestWidth = 0;
        NSUInteger bestHeight = 0;
        TGAttachmentReadImageDimensions(standardPath, &bestWidth, &bestHeight);
        descriptor.pixelWidth = bestWidth;
        descriptor.pixelHeight = bestHeight;
    } else if (TGAttachmentExtensionInSet(descriptor.extension, videoExtensions)) {
        descriptor.kind = TGAttachmentKindVideo;
        descriptor.typeLabel = @"Video";
    } else if (TGAttachmentExtensionInSet(descriptor.extension, audioExtensions)) {
        descriptor.kind = TGAttachmentKindAudio;
        descriptor.typeLabel = @"Audio";
    } else if (TGAttachmentExtensionInSet(descriptor.extension, documentExtensions) || [descriptor.extension length] == 0) {
        descriptor.kind = TGAttachmentKindDocument;
        descriptor.typeLabel = @"Document";
    } else {
        descriptor.kind = TGAttachmentKindDocument;
        descriptor.typeLabel = @"File";
    }

    return descriptor;
}

+ (TGAttachmentDescriptor *)firstDescriptorFromPasteboard:(NSPasteboard *)pasteboard {
    NSArray *descriptors = [TGAttachmentDescriptor descriptorsFromPasteboard:pasteboard maximumCount:1];
    return [descriptors count] > 0 ? [descriptors objectAtIndex:0] : nil;
}

+ (NSArray *)descriptorsFromPasteboard:(NSPasteboard *)pasteboard maximumCount:(NSUInteger)maximumCount {
    if (!pasteboard) {
        return [NSArray array];
    }
    NSArray *paths = [pasteboard propertyListForType:NSFilenamesPboardType];
    if (![paths isKindOfClass:[NSArray class]] || [paths count] == 0) {
        return [NSArray array];
    }
    if (maximumCount == 0) {
        maximumCount = [paths count];
    }
    NSMutableArray *descriptors = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [paths count]; index++) {
        id candidate = [paths objectAtIndex:index];
        if (![candidate isKindOfClass:[NSString class]]) {
            continue;
        }
        TGAttachmentDescriptor *descriptor = [TGAttachmentDescriptor descriptorForPath:(NSString *)candidate];
        if (descriptor && [descriptor isSupported]) {
            [descriptors addObject:descriptor];
            if ([descriptors count] >= maximumCount) {
                break;
            }
        }
    }
    return descriptors;
}

- (BOOL)isSupported {
    return self.kind != TGAttachmentKindUnsupported && [self.path length] > 0 && [self.errorMessage length] == 0;
}

- (BOOL)isLarge {
    return (self.fileSize > (unsigned long long)TGResourcePolicyLargeAttachmentWarningBytes());
}

- (NSString *)readableSize {
    return TGResourcePolicyReadableSize((long long)self.fileSize);
}

- (NSString *)summary {
    NSString *name = [self.fileName length] > 0 ? self.fileName : @"File";
    NSString *type = [self.typeLabel length] > 0 ? self.typeLabel : @"File";
    return [NSString stringWithFormat:@"%@ • %@ • %@", name, type, [self readableSize]];
}

- (void)dealloc {
    [_path release];
    [_fileName release];
    [_extension release];
    [_typeLabel release];
    [_errorMessage release];
    [super dealloc];
}

@end
