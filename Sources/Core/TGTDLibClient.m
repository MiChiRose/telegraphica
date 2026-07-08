#import "TGTDLibClient.h"
#import "../Services/TGKeychainHelper.h"
#import <dlfcn.h>
#import <Security/Security.h>
#import <stdlib.h>

typedef void *(*TGTDJsonClientCreateFunction)(void);
typedef void (*TGTDJsonClientSendFunction)(void *, const char *);
typedef const char *(*TGTDJsonClientReceiveFunction)(void *, double);
typedef const char *(*TGTDJsonClientExecuteFunction)(void *, const char *);
typedef void (*TGTDJsonClientDestroyFunction)(void *);

static NSString * const TGTDLibErrorDomain = @"TelegraphicaTDLibError";
static NSString * const TGTDLibDatabaseEncryptionKeyAccount = @"tdlib_database_encryption_key";

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

- (void)destroyTDLibClient {
    if (_client && _destroyFunction) {
        _destroyFunction(_client);
    }
    _client = NULL;
}

- (void)dealloc {
    [self destroyTDLibClient];
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

- (NSString *)authorizationErrorDescriptionForSummary:(NSString *)summary actionName:(NSString *)actionName {
    NSString *message = [NSString stringWithFormat:@"TDLib rejected %@: %@", actionName, summary];
    if ([summary rangeOfString:@"UPDATE_APP_TO_LOGIN"].location != NSNotFound) {
        message = [message stringByAppendingString:@". Telegram requires a newer client for login; try rebuilding with a newer TDLib/API layer."];
    }
    return message;
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

- (NSString *)tdlibParametersSchemaFromConfiguration:(NSDictionary *)configuration {
    NSString *schema = [self stringValueForKey:@"tdlib_parameters_schema" inConfiguration:configuration required:NO error:NULL];
    if ([schema length] == 0) {
        return @"auto";
    }

    NSString *lowercaseSchema = [schema lowercaseString];
    if ([lowercaseSchema isEqualToString:@"flat"]) {
        return @"current";
    }
    if ([lowercaseSchema isEqualToString:@"nested"]) {
        return @"legacy";
    }
    if ([lowercaseSchema isEqualToString:@"current"] || [lowercaseSchema isEqualToString:@"legacy"] || [lowercaseSchema isEqualToString:@"auto"]) {
        return lowercaseSchema;
    }
    return @"auto";
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

- (NSData *)databaseEncryptionKeyDataWithError:(NSError **)error {
    TGKeychainHelper *keychain = [TGKeychainHelper sharedHelper];
    NSData *existingKey = [keychain readDataForAccount:TGTDLibDatabaseEncryptionKeyAccount];
    if ([existingKey length] > 0) {
        return existingKey;
    }

    NSMutableData *keyData = [NSMutableData dataWithLength:32];
    OSStatus randomStatus = SecRandomCopyBytes(kSecRandomDefault, [keyData length], [keyData mutableBytes]);
    if (randomStatus != errSecSuccess) {
        if (error) {
            *error = [self errorWithDescription:@"Could not generate TDLib database encryption key." code:18];
        }
        return nil;
    }

    if (![keychain saveData:keyData forAccount:TGTDLibDatabaseEncryptionKeyAccount]) {
        if (error) {
            *error = [self errorWithDescription:@"Could not store TDLib database encryption key in Keychain." code:19];
        }
        return nil;
    }

    return keyData;
}

- (NSString *)databaseEncryptionKeyStringWithError:(NSError **)error {
    NSData *encryptionKeyData = [self databaseEncryptionKeyDataWithError:error];
    if ([encryptionKeyData length] == 0) {
        return nil;
    }

    NSString *encryptionKey = [encryptionKeyData base64EncodedStringWithOptions:0];
    if ([encryptionKey length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Could not encode TDLib database encryption key." code:20];
        }
        return nil;
    }
    return encryptionKey;
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

- (NSDictionary *)currentTDLibParametersRequestWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    NSString *encryptionKey = [self databaseEncryptionKeyStringWithError:error];
    if ([encryptionKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [request setObject:@"setTdlibParameters" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-tdlib-parameters-current-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:encryptionKey forKey:@"database_encryption_key"];
    [request removeObjectForKey:@"enable_storage_optimizer"];
    [request removeObjectForKey:@"ignore_file_names"];
    return request;
}

- (NSDictionary *)legacyTDLibParametersRequestWithParameters:(NSDictionary *)parameters {
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setTdlibParameters" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-tdlib-parameters-legacy-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:parameters forKey:@"parameters"];
    return request;
}

- (NSString *)sendTDLibParametersRequest:(NSDictionary *)request schemaName:(NSString *)schemaName timeout:(NSTimeInterval)timeout error:(NSError **)error {
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
                    NSString *message = [NSString stringWithFormat:@"TDLib rejected %@ local parameters: %@", schemaName, summary];
                    *error = [self errorWithDescription:message code:16];
                }
                return nil;
            }
            if (![summary isEqualToString:@"waitTdlibParameters"]) {
                if (receivedOK) {
                    return [NSString stringWithFormat:@"%@ set OK; auth state: %@", schemaName, summary];
                }
                return [NSString stringWithFormat:@"%@ auth state: %@", schemaName, summary];
            }
        }
    }

    if (receivedOK) {
        return [NSString stringWithFormat:@"%@ set OK; waiting for next auth state", schemaName];
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib did not acknowledge %@ local parameters before the probe timed out.", schemaName];
        *error = [self errorWithDescription:message code:17];
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

    NSDictionary *configuration = [self localTDLibConfigurationWithError:NULL];
    NSString *schema = [self tdlibParametersSchemaFromConfiguration:configuration];

    if ([schema isEqualToString:@"legacy"]) {
        NSDictionary *legacyRequest = [self legacyTDLibParametersRequestWithParameters:parameters];
        return [self sendTDLibParametersRequest:legacyRequest schemaName:@"legacy" timeout:timeout error:error];
    }

    NSError *currentError = nil;
    NSError *currentRequestError = nil;
    NSDictionary *currentRequest = [self currentTDLibParametersRequestWithParameters:parameters error:&currentRequestError];
    if (!currentRequest) {
        if (error) {
            *error = currentRequestError;
        }
        return nil;
    }

    NSString *currentResult = [self sendTDLibParametersRequest:currentRequest schemaName:@"current" timeout:timeout error:&currentError];
    if ([currentResult length] > 0) {
        return currentResult;
    }

    if ([schema isEqualToString:@"current"]) {
        if (error) {
            *error = currentError;
        }
        return nil;
    }

    NSString *stateAfterCurrentError = [self authorizationStateSummaryWithTimeout:1.0 error:NULL];
    if (![stateAfterCurrentError isEqualToString:@"waitTdlibParameters"]) {
        if (error) {
            *error = currentError;
        }
        return nil;
    }

    NSError *legacyError = nil;
    NSDictionary *legacyRequest = [self legacyTDLibParametersRequestWithParameters:parameters];
    NSString *legacyResult = [self sendTDLibParametersRequest:legacyRequest schemaName:@"legacy" timeout:timeout error:&legacyError];
    if ([legacyResult length] > 0) {
        return legacyResult;
    }

    if (error) {
        NSString *currentMessage = currentError ? [currentError localizedDescription] : @"current schema failed";
        NSString *legacyMessage = legacyError ? [legacyError localizedDescription] : @"legacy schema failed";
        NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
        *error = [self errorWithDescription:message code:16];
    }
    return nil;
}

- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *authorizationState = nil;
    NSDate *stateDeadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([[NSDate date] compare:stateDeadline] == NSOrderedAscending) {
        NSTimeInterval remaining = [stateDeadline timeIntervalSinceNow];
        NSTimeInterval stateTimeout = remaining < 1.0 ? remaining : 1.0;
        NSError *stateError = nil;
        authorizationState = [self authorizationStateSummaryWithTimeout:stateTimeout error:&stateError];
        if ([authorizationState isEqualToString:@"waitEncryptionKey"]) {
            break;
        }
        if ([authorizationState length] > 0 && ![authorizationState isEqualToString:@"waitTdlibParameters"]) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
    }

    if (![authorizationState isEqualToString:@"waitEncryptionKey"]) {
        if ([authorizationState length] > 0) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib did not reach waitEncryptionKey before the probe timed out. Last auth state: %@", authorizationState];
                *error = [self errorWithDescription:message code:23];
            }
            return nil;
        }
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not reach waitEncryptionKey before the probe timed out." code:23];
        }
        return nil;
    }

    NSString *encryptionKey = [self databaseEncryptionKeyStringWithError:error];
    if ([encryptionKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkDatabaseEncryptionKey" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-db-key-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:encryptionKey forKey:@"encryption_key"];

    NSString *requestJSON = [self JSONStringFromObject:request error:error];
    if (!requestJSON) {
        return nil;
    }

    _sendFunction(_client, [requestJSON UTF8String]);

    BOOL receivedOK = NO;
    NSDate *ackDeadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([[NSDate date] compare:ackDeadline] == NSOrderedAscending) {
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
                    *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib rejected database encryption key: %@", summary] code:21];
                }
                return nil;
            }
            if (![summary isEqualToString:@"waitEncryptionKey"]) {
                if (receivedOK) {
                    return [NSString stringWithFormat:@"check OK; auth state: %@", summary];
                }
                return [NSString stringWithFormat:@"auth state: %@", summary];
            }
        }
    }

    if (receivedOK) {
        return @"check OK; waiting for next auth state";
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not acknowledge database encryption key before the probe timed out." code:22];
    }
    return nil;
}

- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    if ([authorizationState isEqualToString:@"closed"]) {
        [self destroyTDLibClient];
        authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    }

    if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
        if (![self setLocalTDLibParametersWithTimeout:timeout error:error]) {
            return nil;
        }
        authorizationState = [self authorizationStateSummaryWithTimeout:1.0 error:NULL];
        if ([authorizationState length] == 0) {
            authorizationState = @"waitTdlibParameters";
        }
    }

    if ([authorizationState isEqualToString:@"waitTdlibParameters"] || [authorizationState isEqualToString:@"waitEncryptionKey"]) {
        if (![self checkDatabaseEncryptionKeyWithTimeout:timeout error:error]) {
            return nil;
        }
        authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    }

    return authorizationState;
}

- (NSString *)receiveAuthorizationResultForAction:(NSString *)actionName waitingState:(NSString *)waitingState timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
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
                    NSString *message = [self authorizationErrorDescriptionForSummary:summary actionName:actionName];
                    *error = [self errorWithDescription:message code:errorCode];
                }
                return nil;
            }
            if (![summary isEqualToString:waitingState]) {
                if (receivedOK) {
                    return [NSString stringWithFormat:@"%@ accepted; auth state: %@", actionName, summary];
                }
                return [NSString stringWithFormat:@"auth state: %@", summary];
            }
        }
    }

    if (receivedOK) {
        return [NSString stringWithFormat:@"%@ accepted; waiting for next auth state", actionName];
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib did not acknowledge %@ before the probe timed out.", actionName];
        *error = [self errorWithDescription:message code:errorCode];
    }
    return nil;
}

- (NSString *)sendAuthorizationRequest:(NSDictionary *)request actionName:(NSString *)actionName waitingState:(NSString *)waitingState timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    NSString *requestJSON = [self JSONStringFromObject:request error:error];
    if (!requestJSON) {
        return nil;
    }

    _sendFunction(_client, [requestJSON UTF8String]);
    return [self receiveAuthorizationResultForAction:actionName waitingState:waitingState timeout:timeout errorCode:errorCode error:error];
}

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)extraPrefix timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    if (timeout < 0.5) {
        timeout = 0.5;
    } else if (timeout > 15.0) {
        timeout = 15.0;
    }

    NSMutableDictionary *taggedRequest = [NSMutableDictionary dictionaryWithDictionary:request];
    NSString *extra = [NSString stringWithFormat:@"%@-%@-%u",
                       extraPrefix ? extraPrefix : @"telegraphica-request",
                       [[NSProcessInfo processInfo] globallyUniqueString],
                       (unsigned int)arc4random()];
    [taggedRequest setObject:extra forKey:@"@extra"];

    NSString *requestJSON = [self JSONStringFromObject:taggedRequest error:error];
    if (!requestJSON) {
        return nil;
    }

    _sendFunction(_client, [requestJSON UTF8String]);

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
        NSString *summary = [self summaryForAuthorizationStateObject:dictionary];
        if ([summary isEqualToString:@"closed"]) {
            [self destroyTDLibClient];
            if (error) {
                *error = [self errorWithDescription:@"TDLib authorization state closed while waiting for a response." code:errorCode];
            }
            return nil;
        }

        id responseExtra = [dictionary objectForKey:@"@extra"];
        if (![responseExtra isKindOfClass:[NSString class]] || ![(NSString *)responseExtra isEqualToString:extra]) {
            continue;
        }

        id type = [dictionary objectForKey:@"@type"];
        if ([type isKindOfClass:[NSString class]] && [type isEqualToString:@"error"]) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib request failed: %@", summary ? summary : @"error"];
                *error = [self errorWithDescription:message code:errorCode];
            }
            return nil;
        }

        return dictionary;
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not return the requested response before the probe timed out." code:errorCode];
    }
    return nil;
}

- (NSString *)prepareAuthorizationFlowWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if ([authorizationState length] == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"auth state: %@", authorizationState];
}

- (NSArray *)mainChatIDsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 20;
    } else if (safeLimit > 100) {
        safeLimit = 100;
    }

    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    [chatList setObject:@"chatListMain" forKey:@"@type"];

    NSMutableDictionary *getChatsRequest = [NSMutableDictionary dictionary];
    [getChatsRequest setObject:@"getChats" forKey:@"@type"];
    [getChatsRequest setObject:chatList forKey:@"chat_list"];
    [getChatsRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *currentChatsError = nil;
    NSDictionary *chatsResponse = [self sendTDLibRequestAndWaitForExtra:getChatsRequest
                                                            extraPrefix:@"telegraphica-main-chats"
                                                                timeout:timeout
                                                              errorCode:33
                                                                  error:&currentChatsError];
    if (!chatsResponse) {
        NSError *legacyChatsError = nil;
        NSMutableDictionary *legacyGetChatsRequest = [NSMutableDictionary dictionary];
        [legacyGetChatsRequest setObject:@"getChats" forKey:@"@type"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_order"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_chat_id"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

        chatsResponse = [self sendTDLibRequestAndWaitForExtra:legacyGetChatsRequest
                                                  extraPrefix:@"telegraphica-main-chats-legacy"
                                                      timeout:timeout
                                                    errorCode:33
                                                        error:&legacyChatsError];
        if (!chatsResponse && error) {
            NSString *currentMessage = currentChatsError ? [currentChatsError localizedDescription] : @"current getChats schema failed";
            NSString *legacyMessage = legacyChatsError ? [legacyChatsError localizedDescription] : @"legacy getChats schema failed";
            NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
            *error = [self errorWithDescription:message code:33];
        }
    }

    if (!chatsResponse) {
        return nil;
    }

    id chatsType = [chatsResponse objectForKey:@"@type"];
    id chatIDs = [chatsResponse objectForKey:@"chat_ids"];
    if (![chatsType isKindOfClass:[NSString class]] || ![(NSString *)chatsType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChats returned an unexpected response." code:34];
        }
        return nil;
    }

    return chatIDs;
}

- (NSString *)chatTypeSummaryForChatTypeObject:(id)chatTypeObject {
    if (![chatTypeObject isKindOfClass:[NSDictionary class]]) {
        return @"Chat";
    }

    NSDictionary *chatTypeDictionary = (NSDictionary *)chatTypeObject;
    id type = [chatTypeDictionary objectForKey:@"@type"];
    if (![type isKindOfClass:[NSString class]]) {
        return @"Chat";
    }

    if ([(NSString *)type isEqualToString:@"chatTypePrivate"]) {
        return @"Private";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeBasicGroup"]) {
        return @"Group";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeSupergroup"]) {
        id isChannel = [chatTypeDictionary objectForKey:@"is_channel"];
        if ([isChannel respondsToSelector:@selector(boolValue)] && [isChannel boolValue]) {
            return @"Channel";
        }
        return @"Supergroup";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeSecret"]) {
        return @"Secret";
    }

    return @"Chat";
}

- (NSArray *)mainChatPreviewItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load chats. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:35];
        }
        return nil;
    }

    NSArray *chatIDs = [self mainChatIDsWithLimit:limit timeout:timeout error:error];
    if (!chatIDs) {
        return nil;
    }

    NSUInteger returnedChatIDCount = [chatIDs count];
    NSMutableArray *items = [NSMutableArray array];
    NSTimeInterval chatTimeout = timeout;
    if (chatTimeout > 1.0) {
        chatTimeout = 1.0;
    }

    NSUInteger index = 0;
    for (index = 0; index < [chatIDs count]; index++) {
        id chatID = [chatIDs objectAtIndex:index];
        if (!chatID) {
            continue;
        }

        NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
        [getChatRequest setObject:@"getChat" forKey:@"@type"];
        [getChatRequest setObject:chatID forKey:@"chat_id"];

        NSError *chatError = nil;
        NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                               extraPrefix:@"telegraphica-get-chat"
                                                                   timeout:chatTimeout
                                                                 errorCode:36
                                                                     error:&chatError];
        if (!chatResponse) {
            continue;
        }

        id responseType = [chatResponse objectForKey:@"@type"];
        if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chat"]) {
            continue;
        }

        id titleValue = [chatResponse objectForKey:@"title"];
        NSString *title = ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) ? (NSString *)titleValue : @"Untitled";
        NSString *typeSummary = [self chatTypeSummaryForChatTypeObject:[chatResponse objectForKey:@"type"]];
        id unreadValue = [chatResponse objectForKey:@"unread_count"];
        NSNumber *unreadCount = nil;
        if ([unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadCount = [NSNumber numberWithInteger:[unreadValue integerValue]];
        } else {
            unreadCount = [NSNumber numberWithInteger:0];
        }

        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        [item setObject:title forKey:@"title"];
        [item setObject:typeSummary forKey:@"type"];
        [item setObject:unreadCount forKey:@"unread_count"];
        [items addObject:item];
    }

    if (returnedChatIDCount > 0 && [items count] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned chat IDs, but no chat previews could be loaded." code:37];
        }
        return nil;
    }

    return items;
}

- (NSString *)postLoginProbeSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready for post-login probe. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:30];
        }
        return nil;
    }

    NSMutableDictionary *getMeRequest = [NSMutableDictionary dictionary];
    [getMeRequest setObject:@"getMe" forKey:@"@type"];
    NSDictionary *userResponse = [self sendTDLibRequestAndWaitForExtra:getMeRequest
                                                           extraPrefix:@"telegraphica-get-me"
                                                               timeout:timeout
                                                             errorCode:31
                                                                 error:error];
    if (!userResponse) {
        return nil;
    }

    id userType = [userResponse objectForKey:@"@type"];
    if (![userType isKindOfClass:[NSString class]] || ![(NSString *)userType isEqualToString:@"user"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getMe returned an unexpected response." code:32];
        }
        return nil;
    }

    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    [chatList setObject:@"chatListMain" forKey:@"@type"];

    NSMutableDictionary *getChatsRequest = [NSMutableDictionary dictionary];
    [getChatsRequest setObject:@"getChats" forKey:@"@type"];
    [getChatsRequest setObject:chatList forKey:@"chat_list"];
    [getChatsRequest setObject:[NSNumber numberWithInt:20] forKey:@"limit"];

    NSError *currentChatsError = nil;
    NSDictionary *chatsResponse = [self sendTDLibRequestAndWaitForExtra:getChatsRequest
                                                            extraPrefix:@"telegraphica-get-chats"
                                                                timeout:timeout
                                                              errorCode:33
                                                                  error:&currentChatsError];
    if (!chatsResponse) {
        NSError *legacyChatsError = nil;
        NSMutableDictionary *legacyGetChatsRequest = [NSMutableDictionary dictionary];
        [legacyGetChatsRequest setObject:@"getChats" forKey:@"@type"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_order"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_chat_id"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithInt:20] forKey:@"limit"];

        chatsResponse = [self sendTDLibRequestAndWaitForExtra:legacyGetChatsRequest
                                                          extraPrefix:@"telegraphica-get-chats-legacy"
                                                              timeout:timeout
                                                            errorCode:33
                                                                 error:&legacyChatsError];
        if (!chatsResponse && error) {
            NSString *currentMessage = currentChatsError ? [currentChatsError localizedDescription] : @"current getChats schema failed";
            NSString *legacyMessage = legacyChatsError ? [legacyChatsError localizedDescription] : @"legacy getChats schema failed";
            NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
            *error = [self errorWithDescription:message code:33];
        }
    }
    if (!chatsResponse) {
        return nil;
    }

    id chatsType = [chatsResponse objectForKey:@"@type"];
    id chatIDs = [chatsResponse objectForKey:@"chat_ids"];
    if (![chatsType isKindOfClass:[NSString class]] || ![(NSString *)chatsType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChats returned an unexpected response." code:34];
        }
        return nil;
    }

    return [NSString stringWithFormat:@"getMe OK (authorized user object received); getChats OK (%lu chat ids received)", (unsigned long)[(NSArray *)chatIDs count]];
}

- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *trimmedPhone = [phoneNumber stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedPhone length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Phone number is empty." code:24];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitPhoneNumber"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setAuthenticationPhoneNumber" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-auth-phone-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:trimmedPhone forKey:@"phone_number"];
    [request setObject:[NSNull null] forKey:@"settings"];
    return [self sendAuthorizationRequest:request actionName:@"phone number" waitingState:@"waitPhoneNumber" timeout:timeout errorCode:25 error:error];
}

- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *trimmedCode = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedCode length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Authentication code is empty." code:26];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitCode"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkAuthenticationCode" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-auth-code-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:trimmedCode forKey:@"code"];
    return [self sendAuthorizationRequest:request actionName:@"authentication code" waitingState:@"waitCode" timeout:timeout errorCode:27 error:error];
}

- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if ([password length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Authentication password is empty." code:28];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitPassword"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkAuthenticationPassword" forKey:@"@type"];
    [request setObject:[NSString stringWithFormat:@"telegraphica-auth-password-%.0f", [[NSDate date] timeIntervalSince1970]] forKey:@"@extra"];
    [request setObject:password forKey:@"password"];
    return [self sendAuthorizationRequest:request actionName:@"authentication password" waitingState:@"waitPassword" timeout:timeout errorCode:29 error:error];
}

@end
