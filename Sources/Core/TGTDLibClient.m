#import "TGTDLibClient.h"
#import <dlfcn.h>

typedef void *(*TGTDJsonClientCreateFunction)(void);
typedef void (*TGTDJsonClientSendFunction)(void *, const char *);
typedef const char *(*TGTDJsonClientReceiveFunction)(void *, double);
typedef const char *(*TGTDJsonClientExecuteFunction)(void *, const char *);
typedef void (*TGTDJsonClientDestroyFunction)(void *);

static NSString * const TGTDLibErrorDomain = @"TelegraphicaTDLibError";

@interface TGTDLibClient () {
    void *_libraryHandle;
    void *_client;
    TGTDJsonClientCreateFunction _createFunction;
    TGTDJsonClientSendFunction _sendFunction;
    TGTDJsonClientReceiveFunction _receiveFunction;
    TGTDJsonClientExecuteFunction _executeFunction;
    TGTDJsonClientDestroyFunction _destroyFunction;
}
@property (nonatomic, copy) NSString *loadedPath;
@end

@implementation TGTDLibClient

@synthesize loadedPath = _loadedPath;

- (void)dealloc {
    if (_client && _destroyFunction) {
        _destroyFunction(_client);
        _client = NULL;
    }
    if (_libraryHandle) {
        dlclose(_libraryHandle);
        _libraryHandle = NULL;
    }
    [_loadedPath release];
    [super dealloc];
}

- (NSString *)loadedLibraryPath {
    return _loadedPath;
}

- (NSArray *)candidateLibraryPaths {
    NSMutableArray *paths = [NSMutableArray array];
    NSString *environmentPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"TELEGRAPHICA_TDJSON_PATH"];
    if ([environmentPath length] > 0) {
        [paths addObject:environmentPath];
    }

    NSString *frameworksPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Frameworks/libtdjson.dylib"];
    [paths addObject:frameworksPath];
    [paths addObject:@"/usr/local/lib/libtdjson.dylib"];
    [paths addObject:@"/opt/homebrew/lib/libtdjson.dylib"];
    [paths addObject:@"libtdjson.dylib"];
    return paths;
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"Unknown TDLib error")
                                                     forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:TGTDLibErrorDomain code:code userInfo:info];
}

- (BOOL)loadLibraryWithError:(NSError **)error {
    if (_libraryHandle && _createFunction && _sendFunction && _receiveFunction && _executeFunction) {
        return YES;
    }

    NSArray *paths = [self candidateLibraryPaths];
    NSString *lastDLError = nil;
    NSUInteger index = 0;
    for (index = 0; index < [paths count]; index++) {
        NSString *path = [paths objectAtIndex:index];
        const char *fileSystemPath = [path fileSystemRepresentation];
        void *handle = dlopen(fileSystemPath, RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            const char *dlError = dlerror();
            if (dlError) {
                lastDLError = [NSString stringWithUTF8String:dlError];
            }
            continue;
        }

        _libraryHandle = handle;
        self.loadedPath = path;
        break;
    }

    if (!_libraryHandle) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Could not load libtdjson.dylib. Last loader error: %@",
                                 lastDLError ? lastDLError : @"not found"];
            *error = [self errorWithDescription:message code:1];
        }
        return NO;
    }

    _createFunction = (TGTDJsonClientCreateFunction)dlsym(_libraryHandle, "td_json_client_create");
    _sendFunction = (TGTDJsonClientSendFunction)dlsym(_libraryHandle, "td_json_client_send");
    _receiveFunction = (TGTDJsonClientReceiveFunction)dlsym(_libraryHandle, "td_json_client_receive");
    _executeFunction = (TGTDJsonClientExecuteFunction)dlsym(_libraryHandle, "td_json_client_execute");
    _destroyFunction = (TGTDJsonClientDestroyFunction)dlsym(_libraryHandle, "td_json_client_destroy");

    if (!_createFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_create was not exported." code:2];
        }
        return NO;
    }

    if (!_executeFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_execute was not exported." code:3];
        }
        return NO;
    }

    if (!_sendFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_send was not exported." code:4];
        }
        return NO;
    }

    if (!_receiveFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_receive was not exported." code:5];
        }
        return NO;
    }

    return YES;
}

- (BOOL)ensureClientWithError:(NSError **)error {
    if (![self loadLibraryWithError:error]) {
        return NO;
    }

    if (!_client) {
        _client = _createFunction();
    }

    if (!_client) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not create a JSON client." code:6];
        }
        return NO;
    }

    return YES;
}

- (id)JSONObjectFromJSONString:(NSString *)jsonString error:(NSError **)error {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!object) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib returned unparseable JSON: %@", jsonString];
            *error = [self errorWithDescription:message code:7];
        }
        return nil;
    }
    return object;
}

- (NSString *)summaryForAuthorizationStateObject:(id)object {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *dictionary = (NSDictionary *)object;
    id type = [dictionary objectForKey:@"@type"];
    if ([type isKindOfClass:[NSString class]]) {
        if ([type isEqualToString:@"updateAuthorizationState"]) {
            id state = [dictionary objectForKey:@"authorization_state"];
            return [self summaryForAuthorizationStateObject:state];
        }
        if ([type hasPrefix:@"authorizationState"]) {
            NSString *prefix = @"authorizationState";
            if ([type length] > [prefix length]) {
                NSString *shortName = [type substringFromIndex:[prefix length]];
                NSString *first = [[shortName substringToIndex:1] lowercaseString];
                NSString *rest = [shortName substringFromIndex:1];
                return [first stringByAppendingString:rest];
            }
            return type;
        }
        if ([type isEqualToString:@"error"]) {
            id message = [dictionary objectForKey:@"message"];
            if ([message isKindOfClass:[NSString class]]) {
                return [NSString stringWithFormat:@"error: %@", message];
            }
            return @"error";
        }
    }

    return nil;
}

- (NSString *)tdlibProbeSummaryWithError:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    const char *request = "{\"@type\":\"getTextEntities\",\"text\":\"Telegraphica TDLib smoke https://telegram.org @telegraphica\"}";
    const char *result = _executeFunction(_client, request);
    if (!result) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned no response for synchronous getTextEntities probe." code:8];
        }
        return nil;
    }

    NSString *jsonString = [NSString stringWithUTF8String:result];
    id object = [self JSONObjectFromJSONString:jsonString error:error];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib returned an unparseable response: %@", jsonString];
            *error = [self errorWithDescription:message code:9];
        }
        return nil;
    }

    NSDictionary *dictionary = (NSDictionary *)object;
    id type = [dictionary objectForKey:@"@type"];
    if ([type isKindOfClass:[NSString class]] && [type isEqualToString:@"textEntities"]) {
        id entities = [dictionary objectForKey:@"entities"];
        if ([entities isKindOfClass:[NSArray class]]) {
            return [NSString stringWithFormat:@"sync execute OK (%lu text entities)", (unsigned long)[entities count]];
        }
        return @"sync execute OK";
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib synchronous probe returned unexpected response: %@", jsonString];
        *error = [self errorWithDescription:message code:10];
    }
    return nil;
}

- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *extra = [NSString stringWithFormat:@"telegraphica-auth-state-%.0f", [[NSDate date] timeIntervalSince1970]];
    NSString *request = [NSString stringWithFormat:@"{\"@type\":\"getAuthorizationState\",\"@extra\":\"%@\"}", extra];
    _sendFunction(_client, [request UTF8String]);

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        const char *raw = _receiveFunction(_client, 0.25);
        if (!raw) {
            continue;
        }

        NSString *jsonString = [NSString stringWithUTF8String:raw];
        NSError *jsonError = nil;
        id object = [self JSONObjectFromJSONString:jsonString error:&jsonError];
        if (!object) {
            continue;
        }

        NSString *summary = [self summaryForAuthorizationStateObject:object];
        if ([summary length] > 0) {
            return summary;
        }
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not return authorization state before the probe timed out." code:11];
    }
    return nil;
}

@end
