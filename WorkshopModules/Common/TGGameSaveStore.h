#import <Foundation/Foundation.h>

@interface TGGameSaveStore : NSObject {
@private
    NSURL *_dataDirectoryURL;
    NSString *_fileName;
}

- (id)initWithDataDirectoryURL:(NSURL *)dataDirectoryURL fileName:(NSString *)fileName;
- (NSDictionary *)loadDictionaryQuarantiningCorruptFile:(NSError **)error;
- (BOOL)quarantineCurrentSave;
- (BOOL)saveDictionary:(NSDictionary *)dictionary error:(NSError **)error;
- (BOOL)clearData:(NSError **)error;

@end
