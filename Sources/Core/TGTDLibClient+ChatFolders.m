#import "TGTDLibClient+ChatFolders.h"

@interface TGTDLibClient (ChatFoldersPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSString *)safeChatFolderTitleFromObject:(id)titleObject;
@end

static NSArray *TGChatFolderSafeIDArray(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)value count]; index++) {
        id identifier = [(NSArray *)value objectAtIndex:index];
        if ([identifier respondsToSelector:@selector(longLongValue)]) {
            [result addObject:[NSNumber numberWithLongLong:[identifier longLongValue]]];
        }
    }
    return result;
}

static NSString *TGChatFolderSafeAPIKind(id value) {
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value isEqualToString:@"folder"]) {
        return @"folder";
    }
    return @"filter";
}

static void TGChatFolderSetBoolean(NSMutableDictionary *dictionary, NSDictionary *source, NSString *key) {
    [dictionary setObject:[NSNumber numberWithBool:[[source objectForKey:key] boolValue]] forKey:key];
}

@implementation TGTDLibClient (ChatFolders)

- (NSString *)tg_preferredChatFolderAPIKind {
    NSString *loadedPath = [[self loadedLibraryPath] lowercaseString];
    if ([loadedPath rangeOfString:@"mountain-lion"].location != NSNotFound) {
        return @"filter";
    }
    return @"folder";
}

- (NSDictionary *)tg_normalizedChatFolderDefinitionFromResponse:(NSDictionary *)response
                                                           info:(NSDictionary *)info
                                                        apiKind:(NSString *)apiKind {
    NSString *title = [self safeChatFolderTitleFromObject:[response objectForKey:@"name"]];
    if ([title length] == 0) {
        title = [self safeChatFolderTitleFromObject:[response objectForKey:@"title"]];
    }
    if ([title length] == 0) {
        title = [info objectForKey:@"title"];
    }
    id identifier = [info objectForKey:@"id"];
    if ([title length] == 0 || ![identifier respondsToSelector:@selector(integerValue)]) {
        return nil;
    }

    NSMutableDictionary *definition = [NSMutableDictionary dictionary];
    [definition setObject:[NSNumber numberWithInteger:[identifier integerValue]] forKey:@"id"];
    [definition setObject:title forKey:@"title"];
    [definition setObject:apiKind forKey:@"api_kind"];

    NSString *iconName = nil;
    id icon = [response objectForKey:@"icon"];
    if ([icon isKindOfClass:[NSDictionary class]]) {
        id name = [(NSDictionary *)icon objectForKey:@"name"];
        if ([name isKindOfClass:[NSString class]]) {
            iconName = name;
        }
    }
    if ([iconName length] == 0) {
        id name = [response objectForKey:@"icon_name"];
        if ([name isKindOfClass:[NSString class]]) {
            iconName = name;
        }
    }
    if ([iconName length] == 0) {
        id name = [info objectForKey:@"icon_name"];
        if ([name isKindOfClass:[NSString class]]) {
            iconName = name;
        }
    }
    [definition setObject:([iconName length] > 0 ? iconName : @"Custom") forKey:@"icon_name"];

    [definition setObject:TGChatFolderSafeIDArray([response objectForKey:@"pinned_chat_ids"]) forKey:@"pinned_chat_ids"];
    [definition setObject:TGChatFolderSafeIDArray([response objectForKey:@"included_chat_ids"]) forKey:@"included_chat_ids"];
    [definition setObject:TGChatFolderSafeIDArray([response objectForKey:@"excluded_chat_ids"]) forKey:@"excluded_chat_ids"];
    TGChatFolderSetBoolean(definition, response, @"exclude_muted");
    TGChatFolderSetBoolean(definition, response, @"exclude_read");
    TGChatFolderSetBoolean(definition, response, @"exclude_archived");
    TGChatFolderSetBoolean(definition, response, @"include_contacts");
    TGChatFolderSetBoolean(definition, response, @"include_non_contacts");
    TGChatFolderSetBoolean(definition, response, @"include_bots");
    TGChatFolderSetBoolean(definition, response, @"include_groups");
    TGChatFolderSetBoolean(definition, response, @"include_channels");
    [definition setObject:[NSNumber numberWithBool:[[response objectForKey:@"is_shareable"] boolValue]]
                   forKey:@"is_shareable"];
    id colorID = [response objectForKey:@"color_id"];
    [definition setObject:([colorID respondsToSelector:@selector(integerValue)] ? colorID : [NSNumber numberWithInteger:-1])
                   forKey:@"color_id"];
    [definition setObject:[NSNumber numberWithBool:[self chatFolderAPIKindSupportsSharing:apiKind]]
                   forKey:@"supports_sharing"];
    return definition;
}

- (NSArray *)chatFolderDefinitionsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSArray *infos = [self chatFilterInfoItemsWithTimeout:timeout];
    if (![infos isKindOfClass:[NSArray class]] || [infos count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *definitions = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [infos count]; index++) {
        id infoObject = [infos objectAtIndex:index];
        if (![infoObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *info = (NSDictionary *)infoObject;
        id identifier = [info objectForKey:@"id"];
        if (![identifier respondsToSelector:@selector(integerValue)]) {
            continue;
        }
        NSString *apiKind = TGChatFolderSafeAPIKind([info objectForKey:@"api_kind"]);
        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        if ([apiKind isEqualToString:@"folder"]) {
            [request setObject:@"getChatFolder" forKey:@"@type"];
            [request setObject:[NSNumber numberWithInteger:[identifier integerValue]] forKey:@"chat_folder_id"];
        } else {
            [request setObject:@"getChatFilter" forKey:@"@type"];
            [request setObject:[NSNumber numberWithInteger:[identifier integerValue]] forKey:@"chat_filter_id"];
        }

        NSError *currentError = nil;
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                            extraPrefix:@"telegraphica-chat-folder-get"
                                                                timeout:timeout
                                                              errorCode:330
                                                                  error:&currentError];
        NSString *expectedType = [apiKind isEqualToString:@"folder"] ? @"chatFolder" : @"chatFilter";
        if (![[response objectForKey:@"@type"] isEqualToString:expectedType]) {
            if (error && !*error && currentError) {
                *error = currentError;
            }
            continue;
        }
        NSDictionary *definition = [self tg_normalizedChatFolderDefinitionFromResponse:response
                                                                                   info:info
                                                                                apiKind:apiKind];
        if (definition) {
            [definitions addObject:definition];
        }
    }
    return definitions;
}

- (NSDictionary *)tg_chatFolderObjectFromDefinition:(NSDictionary *)definition apiKind:(NSString *)apiKind {
    NSString *title = [definition objectForKey:@"title"];
    NSString *iconName = [definition objectForKey:@"icon_name"];
    if ([iconName length] == 0) {
        iconName = @"Custom";
    }

    NSMutableDictionary *folder = [NSMutableDictionary dictionary];
    if ([apiKind isEqualToString:@"folder"]) {
        NSDictionary *formattedText = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"formattedText", @"@type",
                                       title, @"text",
                                       [NSArray array], @"entities",
                                       nil];
        NSDictionary *folderName = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"chatFolderName", @"@type",
                                    formattedText, @"text",
                                    [NSNumber numberWithBool:NO], @"animate_custom_emoji",
                                    nil];
        NSDictionary *icon = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"chatFolderIcon", @"@type",
                              iconName, @"name",
                              nil];
        [folder setObject:@"chatFolder" forKey:@"@type"];
        [folder setObject:folderName forKey:@"name"];
        [folder setObject:icon forKey:@"icon"];
        id colorID = [definition objectForKey:@"color_id"];
        [folder setObject:([colorID respondsToSelector:@selector(integerValue)] ? colorID : [NSNumber numberWithInteger:-1])
                   forKey:@"color_id"];
        [folder setObject:[NSNumber numberWithBool:[[definition objectForKey:@"is_shareable"] boolValue]]
                   forKey:@"is_shareable"];
    } else {
        [folder setObject:@"chatFilter" forKey:@"@type"];
        [folder setObject:title forKey:@"title"];
        [folder setObject:iconName forKey:@"icon_name"];
    }

    [folder setObject:TGChatFolderSafeIDArray([definition objectForKey:@"pinned_chat_ids"]) forKey:@"pinned_chat_ids"];
    [folder setObject:TGChatFolderSafeIDArray([definition objectForKey:@"included_chat_ids"]) forKey:@"included_chat_ids"];
    [folder setObject:TGChatFolderSafeIDArray([definition objectForKey:@"excluded_chat_ids"]) forKey:@"excluded_chat_ids"];
    NSArray *booleanKeys = [NSArray arrayWithObjects:
                            @"exclude_muted",
                            @"exclude_read",
                            @"exclude_archived",
                            @"include_contacts",
                            @"include_non_contacts",
                            @"include_bots",
                            @"include_groups",
                            @"include_channels",
                            nil];
    NSUInteger index = 0;
    for (index = 0; index < [booleanKeys count]; index++) {
        NSString *key = [booleanKeys objectAtIndex:index];
        [folder setObject:[NSNumber numberWithBool:[[definition objectForKey:key] boolValue]] forKey:key];
    }
    return folder;
}

- (NSNumber *)tg_saveChatFolderDefinition:(NSDictionary *)definition
                                  apiKind:(NSString *)apiKind
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error {
    id folderID = [definition objectForKey:@"id"];
    BOOL editing = [folderID respondsToSelector:@selector(integerValue)] && [folderID integerValue] > 0;
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    NSDictionary *folder = [self tg_chatFolderObjectFromDefinition:definition apiKind:apiKind];
    if ([apiKind isEqualToString:@"folder"]) {
        [request setObject:(editing ? @"editChatFolder" : @"createChatFolder") forKey:@"@type"];
        if (editing) {
            [request setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_folder_id"];
        }
    } else {
        [request setObject:(editing ? @"editChatFilter" : @"createChatFilter") forKey:@"@type"];
        if (editing) {
            [request setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_filter_id"];
        }
    }
    [request setObject:folder forKey:([apiKind isEqualToString:@"folder"] ? @"folder" : @"filter")];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:(editing ? @"telegraphica-chat-folder-edit" : @"telegraphica-chat-folder-create")
                                                            timeout:timeout
                                                          errorCode:331
                                                              error:error];
    NSString *expectedType = [apiKind isEqualToString:@"folder"] ? @"chatFolderInfo" : @"chatFilterInfo";
    id responseID = [response objectForKey:@"id"];
    if ([[response objectForKey:@"@type"] isEqualToString:expectedType] &&
        [responseID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[responseID integerValue]];
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected response while saving the chat folder." code:332];
    }
    return nil;
}

- (NSNumber *)saveChatFolderDefinition:(NSDictionary *)definition timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![definition isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat folder data is missing." code:333];
        }
        return nil;
    }
    NSString *title = [[definition objectForKey:@"title"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0 || [title length] > 12 || [title rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
        if (error) {
            *error = [self errorWithDescription:@"A chat folder name must contain 1 to 12 characters without line breaks." code:334];
        }
        return nil;
    }
    NSMutableDictionary *safeDefinition = [NSMutableDictionary dictionaryWithDictionary:definition];
    [safeDefinition setObject:title forKey:@"title"];

    NSString *apiKind = nil;
    id suppliedKind = [safeDefinition objectForKey:@"api_kind"];
    if ([suppliedKind isKindOfClass:[NSString class]] && [(NSString *)suppliedKind length] > 0) {
        apiKind = TGChatFolderSafeAPIKind(suppliedKind);
    } else {
        apiKind = [self tg_preferredChatFolderAPIKind];
    }
    [safeDefinition setObject:apiKind forKey:@"api_kind"];

    NSError *saveError = nil;
    NSNumber *savedID = [self tg_saveChatFolderDefinition:safeDefinition apiKind:apiKind timeout:timeout error:&saveError];
    BOOL creating = ![[safeDefinition objectForKey:@"id"] respondsToSelector:@selector(integerValue)];
    if (!savedID && creating) {
        NSString *fallbackKind = [apiKind isEqualToString:@"folder"] ? @"filter" : @"folder";
        [safeDefinition setObject:fallbackKind forKey:@"api_kind"];
        NSError *fallbackError = nil;
        savedID = [self tg_saveChatFolderDefinition:safeDefinition apiKind:fallbackKind timeout:timeout error:&fallbackError];
        if (!savedID) {
            saveError = fallbackError ? fallbackError : saveError;
        }
    }
    if (!savedID && error) {
        *error = saveError ? saveError : [self errorWithDescription:@"The chat folder could not be saved." code:335];
    }
    return savedID;
}

- (BOOL)deleteChatFolderWithID:(NSNumber *)folderID apiKind:(NSString *)apiKind timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![folderID respondsToSelector:@selector(integerValue)] || [folderID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"Chat folder identifier is missing." code:336];
        }
        return NO;
    }
    NSString *safeKind = TGChatFolderSafeAPIKind(apiKind);
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    if ([safeKind isEqualToString:@"folder"]) {
        [request setObject:@"deleteChatFolder" forKey:@"@type"];
        [request setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_folder_id"];
        [request setObject:[NSArray array] forKey:@"leave_chat_ids"];
    } else {
        [request setObject:@"deleteChatFilter" forKey:@"@type"];
        [request setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_filter_id"];
    }
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-delete"
                                                            timeout:timeout
                                                          errorCode:337
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected response while deleting the chat folder." code:338];
    }
    return NO;
}

- (BOOL)chatFolderAPIKindSupportsSharing:(NSString *)apiKind {
    return [apiKind isKindOfClass:[NSString class]] && [apiKind isEqualToString:@"folder"];
}

- (NSString *)shareLinkForChatFolderID:(NSNumber *)folderID title:(NSString *)title timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![folderID respondsToSelector:@selector(integerValue)] || [folderID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"Save the chat folder before sharing it." code:339];
        }
        return nil;
    }

    NSMutableDictionary *linksRequest = [NSMutableDictionary dictionary];
    [linksRequest setObject:@"getChatFolderInviteLinks" forKey:@"@type"];
    [linksRequest setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_folder_id"];
    NSError *linksError = nil;
    NSDictionary *linksResponse = [self sendTDLibRequestAndWaitForExtra:linksRequest
                                                            extraPrefix:@"telegraphica-chat-folder-links"
                                                                timeout:timeout
                                                              errorCode:340
                                                                  error:&linksError];
    id existingLinks = [linksResponse objectForKey:@"invite_links"];
    if ([[linksResponse objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLinks"] &&
        [existingLinks isKindOfClass:[NSArray class]] &&
        [(NSArray *)existingLinks count] > 0) {
        id firstLink = [(NSArray *)existingLinks objectAtIndex:0];
        id inviteLink = [firstLink isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)firstLink objectForKey:@"invite_link"] : nil;
        if ([inviteLink isKindOfClass:[NSString class]] && [(NSString *)inviteLink length] > 0) {
            return inviteLink;
        }
    }

    NSMutableDictionary *chatsRequest = [NSMutableDictionary dictionary];
    [chatsRequest setObject:@"getChatsForChatFolderInviteLink" forKey:@"@type"];
    [chatsRequest setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_folder_id"];
    NSError *chatsError = nil;
    NSDictionary *chatsResponse = [self sendTDLibRequestAndWaitForExtra:chatsRequest
                                                            extraPrefix:@"telegraphica-chat-folder-shareable-chats"
                                                                timeout:timeout
                                                              errorCode:341
                                                                  error:&chatsError];
    NSArray *chatIDs = TGChatFolderSafeIDArray([chatsResponse objectForKey:@"chat_ids"]);
    if (![[chatsResponse objectForKey:@"@type"] isEqualToString:@"chats"] || [chatIDs count] == 0) {
        if (error) {
            *error = chatsError ? chatsError : [self errorWithDescription:@"This folder has no chats that can be shared by invite link." code:342];
        }
        return nil;
    }

    NSString *safeName = [title isKindOfClass:[NSString class]] ? title : @"";
    if ([safeName length] > 32) {
        safeName = [safeName substringToIndex:32];
    }
    NSMutableDictionary *createRequest = [NSMutableDictionary dictionary];
    [createRequest setObject:@"createChatFolderInviteLink" forKey:@"@type"];
    [createRequest setObject:[NSNumber numberWithInteger:[folderID integerValue]] forKey:@"chat_folder_id"];
    [createRequest setObject:safeName forKey:@"name"];
    [createRequest setObject:chatIDs forKey:@"chat_ids"];
    NSDictionary *createResponse = [self sendTDLibRequestAndWaitForExtra:createRequest
                                                              extraPrefix:@"telegraphica-chat-folder-share"
                                                                  timeout:timeout
                                                                errorCode:343
                                                                    error:error];
    id inviteLink = [createResponse objectForKey:@"invite_link"];
    if ([[createResponse objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLink"] &&
        [inviteLink isKindOfClass:[NSString class]] &&
        [(NSString *)inviteLink length] > 0) {
        return inviteLink;
    }
    if (error && createResponse && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected response while creating the folder link." code:344];
    }
    return nil;
}

@end
