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

- (NSString *)applicationSupportPathWithError:(NSError **)error {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *path = [basePath stringByAppendingPathComponent:@"Telegraphica"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }
    return path;
}

- (NSString *)cachePathWithError:(NSError **)error {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *path = [basePath stringByAppendingPathComponent:@"Telegraphica"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }
    return path;
}

- (NSString *)localTDLibConfigurationPathWithError:(NSError **)error {
    NSString *supportPath = [self applicationSupportPathWithError:error];
    if (!supportPath) {
        return nil;
    }
    return [supportPath stringByAppendingPathComponent:@"tdlib-config.plist"];
}

- (NSDictionary *)localTDLibConfigurationWithError:(NSError **)error {
    NSString *configPath = [self localTDLibConfigurationPathWithError:error];
    if (!configPath) {
        return nil;
    }

    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (![configuration isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Local TDLib config was not found or is not a plist dictionary: %@", configPath];
            *error = [self errorWithDescription:message code:12];
        }
        return nil;
    }

    return configuration;
}

- (NSString *)stringValueForKey:(NSString *)key inConfiguration:(NSDictionary *)configuration required:(BOOL)required error:(NSError **)error {
    id value = [configuration objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return value;
    }

    if (required && error) {
        NSString *message = [NSString stringWithFormat:@"Local TDLib config is missing required key '%@'.", key];
        *error = [self errorWithDescription:message code:13];
    }
    return nil;
}

- (NSNumber *)apiIDFromConfiguration:(NSDictionary *)configuration error:(NSError **)error {
    id value = [configuration objectForKey:@"api_id"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        NSInteger integerValue = [(NSString *)value integerValue];
        if (integerValue > 0) {
            return [NSNumber numberWithInteger:integerValue];
        }
    }

    if (error) {
        *error = [self errorWithDescription:@"Local TDLib config is missing numeric required key 'api_id'." code:14];
    }
    return nil;
}

- (NSNumber *)boolValueForKey:(NSString *)key inConfiguration:(NSDictionary *)configuration defaultValue:(BOOL)defaultValue {
    id value = [configuration objectForKey:key];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [NSNumber numberWithBool:[value boolValue]];
    }
    return [NSNumber numberWithBool:defaultValue];
}

- (NSString *)defaultSystemLanguageCode {
    NSArray *languages = [NSLocale preferredLanguages];
    if ([languages count] > 0 && [[languages objectAtIndex:0] length] > 0) {
        return [languages objectAtIndex:0];
    }
    return @"en";
}

- (NSString *)applicationVersionString {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if ([version length] == 0) {
        return @"0.1.0";
    }
    return version;
}

- (BOOL)ensureDirectoryAtPath:(NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error];
}

- (NSDictionary *)localTDLibParametersWithError:(NSError **)error {
    NSDictionary *configuration = [self localTDLibConfigurationWithError:error];
    if (!configuration) {
        return nil;
    }

    NSNumber *apiID = [self apiIDFromConfiguration:configuration error:error];
    NSString *apiHash = [self stringValueForKey:@"api_hash" inConfiguration:configuration required:YES error:error];
    if (!apiID || [apiHash length] == 0) {
        return nil;
    }

    NSString *supportPath = [self applicationSupportPathWithError:error];
    NSString *cachePath = [self cachePathWithError:error];
    if (!supportPath || !cachePath) {
        return nil;
    }

    NSString *databasePath = [supportPath stringByAppendingPathComponent:@"tdlib"];
    NSString *filesPath = [cachePath stringByAppendingPathComponent:@"tdlib-files"];
    if (![self ensureDirectoryAtPath:databasePath error:error] || ![self ensureDirectoryAtPath:filesPath error:error]) {
        return nil;
    }

    NSString *systemLanguageCode = [self stringValueForKey:@"system_language_code" inConfiguration:configuration required:NO error:NULL];
    if ([systemLanguageCode length] == 0) {
        systemLanguageCode = [self defaultSystemLanguageCode];
    }

    NSString *deviceModel = [self stringValueForKey:@"device_model" inConfiguration:configuration required:NO error:NULL];
    if ([deviceModel length] == 0) {
        deviceModel = @"Mac";
    }

    NSString *systemVersion = [self stringValueForKey:@"system_version" inConfiguration:configuration required:NO error:NULL];
    if ([systemVersion length] == 0) {
        systemVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
    }

    NSString *applicationVersion = [self stringValueForKey:@"application_version" inConfiguration:configuration required:NO error:NULL];
    if ([applicationVersion length] == 0) {
        applicationVersion = [self applicationVersionString];
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setObject:[self boolValueForKey:@"use_test_dc" inConfiguration:configuration defaultValue:NO] forKey:@"use_test_dc"];
    [parameters setObject:databasePath forKey:@"database_directory"];
    [parameters setObject:filesPath forKey:@"files_directory"];
    [parameters setObject:[self boolValueForKey:@"use_file_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_file_database"];
    [parameters setObject:[self boolValueForKey:@"use_chat_info_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_chat_info_database"];
    [parameters setObject:[self boolValueForKey:@"use_message_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_message_database"];
    [parameters setObject:[self boolValueForKey:@"use_secret_chats" inConfiguration:configuration defaultValue:NO] forKey:@"use_secret_chats"];
    [parameters setObject:apiID forKey:@"api_id"];
    [parameters setObject:apiHash forKey:@"api_hash"];
    [parameters setObject:systemLanguageCode forKey:@"system_language_code"];
    [parameters setObject:deviceModel forKey:@"device_model"];
    [parameters setObject:systemVersion forKey:@"system_version"];
    [parameters setObject:applicationVersion forKey:@"application_version"];
    [parameters setObject:[self boolValueForKey:@"enable_storage_optimizer" inConfiguration:configuration defaultValue:YES] forKey:@"enable_storage_optimizer"];
    [parameters setObject:[self boolValueForKey:@"ignore_file_names" inConfiguration:configuration defaultValue:NO] forKey:@"ignore_file_names"];
    return parameters;
}

- (NSString *)JSONStringFromObject:(id)object error:(NSError **)error {
    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&jsonError];
    if (!data) {
        if (error) {
            *error = [self errorWithDescription:@"Could not serialize TDLib JSON request." code:15];
        }
        return nil;
    }
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
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

- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitTdlibParameters"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSDictionary *parameters = [self localTDLibParametersWithError:error];
    if (!parameters) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setTdlibParameters" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-tdlib-parameters-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:parameters forKey:@"parameters"];

    NSString *requestJSON = [self JSONStringFromObject:request error:error];
    if (!requestJSON) {
        return nil;
    }

    _sendFunction(_client, [requestJSON UTF8String]);

    BOOL receivedOK = NO;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        const char *raw = _receiveFunction(_client, 0.25);
        if (!raw) {
            continue;
        }

        NSString *jsonString = [NSString stringWithUTF8String:raw];
        NSError *jsonError = nil;
        id object = [self JSONObjectFromJSONString:jsonString error:&jsonError];
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *dictionary = (NSDictionary *)object;
        id type = [dictionary objectForKey:@"@type"];
        if ([type isKindOfClass:[NSString class]] && [type isEqualToString:@"ok"]) {
            receivedOK = YES;
            continue;
        }

        NSString *summary = [self summaryForAuthorizationStateObject:dictionary];
        if ([summary length] > 0) {
            if ([summary hasPrefix:@"error"]) {
                if (error) {
                    *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib rejected local parameters: %@", summary] code:16];
                }
                return nil;
            }
            if (![summary isEqualToString:@"waitTdlibParameters"]) {
                if (receivedOK) {
                    return [NSString stringWithFormat:@"set OK; auth state: %@", summary];
                }
                return [NSString stringWithFormat:@"auth state: %@", summary];
            }
        }
    }

    if (receivedOK) {
        return @"set OK; waiting for next auth state";
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not acknowledge local parameters before the probe timed out." code:17];
    }
    return nil;
}

@end
