#import "TGTDLibClient+ChatFolders.h"
#import "TGChatFolderSupport.h"
#import "TGTDLibCapabilities.h"

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
    return TGChatFolderSafeIdentifierArray(value);
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

- (BOOL)tg_canUseAdvancedSharedFoldersWithError:(NSError **)error {
    TGTDLibCapabilities *capabilities = [self capabilities];
    if ([capabilities lane] == TGTDLibLaneMountainLionFallback) {
        if (error) {
            *error = [self errorWithDescription:@"Shared folder links are unavailable in the OS X 10.8 fallback TDLib." code:356];
        }
        return NO;
    }
    if ([capabilities supportStateForCapability:TGTDLibCapabilitySharedChatFolders] == TGTDLibCapabilityStateUnsupported) {
        if (error) {
            NSString *reason = [capabilities reasonForCapability:TGTDLibCapabilitySharedChatFolders];
            *error = [self errorWithDescription:([reason length] > 0 ? reason : @"The loaded TDLib does not support shared chat folders.") code:357];
        }
        return NO;
    }
    return YES;
}

- (NSString *)tg_preferredChatFolderAPIKind {
    if ([[self capabilities] lane] == TGTDLibLaneMountainLionFallback) {
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

- (BOOL)reorderChatFolderDefinitions:(NSArray *)definitions timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![definitions isKindOfClass:[NSArray class]] || [definitions count] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"There are no chat folders to reorder." code:345];
        }
        return NO;
    }

    NSMutableArray *folderIDs = [NSMutableArray arrayWithCapacity:[definitions count]];
    BOOL legacyOnly = YES;
    NSUInteger index = 0;
    for (index = 0; index < [definitions count]; index++) {
        NSDictionary *definition = [[definitions objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [definitions objectAtIndex:index] : nil;
        id identifier = [definition objectForKey:@"id"];
        if (![identifier respondsToSelector:@selector(integerValue)] || [identifier integerValue] <= 0) {
            if (error) {
                *error = [self errorWithDescription:@"A chat folder identifier is missing from the requested order." code:346];
            }
            return NO;
        }
        [folderIDs addObject:[NSNumber numberWithInteger:[identifier integerValue]]];
        if ([[definition objectForKey:@"api_kind"] isEqualToString:@"folder"]) {
            legacyOnly = NO;
        }
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:(legacyOnly ? @"reorderChatFilters" : @"reorderChatFolders") forKey:@"@type"];
    [request setObject:folderIDs forKey:(legacyOnly ? @"chat_filter_ids" : @"chat_folder_ids")];
    [request setObject:[NSNumber numberWithInteger:0] forKey:@"main_chat_list_position"];

    NSError *requestError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-reorder"
                                                            timeout:timeout
                                                          errorCode:347
                                                              error:&requestError];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }

    if (!legacyOnly) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionary];
        [legacyRequest setObject:@"reorderChatFilters" forKey:@"@type"];
        [legacyRequest setObject:folderIDs forKey:@"chat_filter_ids"];
        [legacyRequest setObject:[NSNumber numberWithInteger:0] forKey:@"main_chat_list_position"];
        NSError *legacyError = nil;
        NSDictionary *legacyResponse = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                                                 extraPrefix:@"telegraphica-chat-folder-reorder-legacy"
                                                                     timeout:timeout
                                                                   errorCode:348
                                                                       error:&legacyError];
        if ([[legacyResponse objectForKey:@"@type"] isEqualToString:@"ok"]) {
            return YES;
        }
        if (legacyError) {
            requestError = legacyError;
        }
    }

    if (error) {
        *error = requestError ? requestError : [self errorWithDescription:@"TDLib could not change the chat folder order." code:349];
    }
    return NO;
}

- (NSDictionary *)chatFolderInvitePreviewForLink:(NSString *)inviteLink
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError **)error {
    NSString *safeLink = [inviteLink isKindOfClass:[NSString class]]
        ? [inviteLink stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    if ([safeLink length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Enter a chat folder invite link." code:350];
        }
        return nil;
    }

    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"checkChatFolderInviteLink", @"@type",
                             safeLink, @"invite_link",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-import-check"
                                                            timeout:timeout
                                                          errorCode:351
                                                              error:error];
    if (![[response objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLinkInfo"]) {
        if (error && response && !*error) {
            *error = [self errorWithDescription:@"TDLib returned an unexpected response for the folder link." code:352];
        }
        return nil;
    }

    NSDictionary *folderInfo = [[response objectForKey:@"chat_folder_info"] isKindOfClass:[NSDictionary class]]
        ? [response objectForKey:@"chat_folder_info"]
        : [NSDictionary dictionary];
    NSString *title = [self safeChatFolderTitleFromObject:[folderInfo objectForKey:@"name"]];
    if ([title length] == 0) {
        title = [self safeChatFolderTitleFromObject:[folderInfo objectForKey:@"title"]];
    }
    if ([title length] == 0) {
        title = @"Telegram";
    }
    NSArray *missingChatIDs = TGChatFolderSafeIDArray([response objectForKey:@"missing_chat_ids"]);
    NSArray *addedChatIDs = TGChatFolderSafeIDArray([response objectForKey:@"added_chat_ids"]);
    return [NSDictionary dictionaryWithObjectsAndKeys:
            safeLink, @"invite_link",
            title, @"title",
            missingChatIDs, @"missing_chat_ids",
            addedChatIDs, @"added_chat_ids",
            nil];
}

- (BOOL)importChatFolderWithInviteLink:(NSString *)inviteLink
                               chatIDs:(NSArray *)chatIDs
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    NSString *safeLink = [inviteLink isKindOfClass:[NSString class]]
        ? [inviteLink stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    NSArray *safeChatIDs = TGChatFolderSafeIDArray(chatIDs);
    if ([safeLink length] == 0 || [safeChatIDs count] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"The folder link contains no new chats to import." code:353];
        }
        return NO;
    }

    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"addChatFolderByInviteLink", @"@type",
                             safeLink, @"invite_link",
                             safeChatIDs, @"chat_ids",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-import"
                                                            timeout:timeout
                                                          errorCode:354
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib could not import the chat folder." code:355];
    }
    return NO;
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

- (NSArray *)chatFolderInviteLinksForFolderID:(NSNumber *)folderID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    if (![folderID respondsToSelector:@selector(integerValue)] || [folderID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"Save the chat folder before managing its links." code:358];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatFolderInviteLinks", @"@type",
                             folderID, @"chat_folder_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-links-all"
                                                            timeout:timeout
                                                          errorCode:359
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLinks"]) {
        return TGChatFolderNormalizeInviteLinks(response);
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected folder-link list." code:360];
    }
    return nil;
}

- (NSArray *)shareableChatIDsForFolderID:(NSNumber *)folderID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatsForChatFolderInviteLink", @"@type",
                             folderID, @"chat_folder_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-shareable-all"
                                                            timeout:timeout
                                                          errorCode:361
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chats"]) {
        return TGChatFolderSafeIdentifierArray([response objectForKey:@"chat_ids"]);
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected shareable-chat list." code:362];
    }
    return nil;
}

- (NSDictionary *)createChatFolderInviteLinkForFolderID:(NSNumber *)folderID
                                                    name:(NSString *)name
                                                 chatIDs:(NSArray *)chatIDs
                                                 timeout:(NSTimeInterval)timeout
                                                   error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    NSString *safeName = [name isKindOfClass:[NSString class]] ? name : @"";
    if ([safeName length] > 32) {
        safeName = [safeName substringToIndex:32];
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"createChatFolderInviteLink", @"@type",
                             folderID, @"chat_folder_id",
                             safeName, @"name",
                             TGChatFolderSafeIdentifierArray(chatIDs), @"chat_ids",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-link-create"
                                                            timeout:timeout
                                                          errorCode:363
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLink"]) {
        NSArray *normalized = TGChatFolderNormalizeInviteLinks([NSDictionary dictionaryWithObjectsAndKeys:
                                                                @"chatFolderInviteLinks", @"@type",
                                                                [NSArray arrayWithObject:response], @"invite_links",
                                                                nil]);
        return [normalized count] > 0 ? [normalized objectAtIndex:0] : nil;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib could not create the folder link." code:364];
    }
    return nil;
}

- (NSDictionary *)editChatFolderInviteLinkForFolderID:(NSNumber *)folderID
                                            inviteLink:(NSString *)inviteLink
                                                  name:(NSString *)name
                                               chatIDs:(NSArray *)chatIDs
                                               timeout:(NSTimeInterval)timeout
                                                 error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    NSString *safeName = [name isKindOfClass:[NSString class]] ? name : @"";
    if ([safeName length] > 32) {
        safeName = [safeName substringToIndex:32];
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"editChatFolderInviteLink", @"@type",
                             folderID, @"chat_folder_id",
                             inviteLink, @"invite_link",
                             safeName, @"name",
                             TGChatFolderSafeIdentifierArray(chatIDs), @"chat_ids",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-link-edit"
                                                            timeout:timeout
                                                          errorCode:365
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLink"]) {
        NSArray *normalized = TGChatFolderNormalizeInviteLinks([NSDictionary dictionaryWithObjectsAndKeys:
                                                                @"chatFolderInviteLinks", @"@type",
                                                                [NSArray arrayWithObject:response], @"invite_links",
                                                                nil]);
        return [normalized count] > 0 ? [normalized objectAtIndex:0] : nil;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib could not update the folder link." code:366];
    }
    return nil;
}

- (BOOL)deleteChatFolderInviteLinkForFolderID:(NSNumber *)folderID
                                   inviteLink:(NSString *)inviteLink
                                      timeout:(NSTimeInterval)timeout
                                        error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"deleteChatFolderInviteLink", @"@type",
                             folderID, @"chat_folder_id",
                             inviteLink, @"invite_link",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-link-delete"
                                                            timeout:timeout
                                                          errorCode:367
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib could not delete the folder link." code:368];
    }
    return NO;
}

- (NSArray *)newChatIDsForChatFolderID:(NSNumber *)folderID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatFolderNewChats", @"@type",
                             folderID, @"chat_folder_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-new-chats"
                                                            timeout:timeout
                                                          errorCode:369
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chats"]) {
        return TGChatFolderSafeIdentifierArray([response objectForKey:@"chat_ids"]);
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected list of suggested chats." code:370];
    }
    return nil;
}

- (BOOL)processNewChatIDs:(NSArray *)chatIDs
          forChatFolderID:(NSNumber *)folderID
                  timeout:(NSTimeInterval)timeout
                    error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"processChatFolderNewChats", @"@type",
                             folderID, @"chat_folder_id",
                             TGChatFolderSafeIdentifierArray(chatIDs), @"added_chat_ids",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-folder-new-chats-process"
                                                            timeout:timeout
                                                          errorCode:371
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib could not process the suggested chats." code:372];
    }
    return NO;
}

- (NSArray *)recommendedChatFolderDefinitionsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self tg_canUseAdvancedSharedFoldersWithError:error]) {
        return nil;
    }
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:[NSDictionary dictionaryWithObject:@"getRecommendedChatFolders" forKey:@"@type"]
                                                        extraPrefix:@"telegraphica-chat-folder-recommended"
                                                            timeout:timeout
                                                          errorCode:373
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"recommendedChatFolders"]) {
        return TGChatFolderNormalizeRecommendedFolders(response);
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected recommended-folder list." code:374];
    }
    return nil;
}

- (NSDictionary *)chatFolderServerLimitsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSArray *names = [NSArray arrayWithObjects:
                      @"chat_folder_count_max",
                      @"chat_folder_chosen_chat_count_max",
                      @"chat_folder_invite_link_count_max",
                      @"added_shareable_chat_folder_count_max",
                      @"chat_folder_new_chats_update_period",
                      nil];
    NSMutableDictionary *limits = [NSMutableDictionary dictionary];
    NSError *firstError = nil;
    NSUInteger index = 0;
    for (index = 0; index < [names count]; index++) {
        NSString *name = [names objectAtIndex:index];
        NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"getOption", @"@type",
                                 name, @"name",
                                 nil];
        NSError *optionError = nil;
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                            extraPrefix:@"telegraphica-chat-folder-limit"
                                                                timeout:timeout
                                                              errorCode:375
                                                                  error:&optionError];
        NSNumber *value = TGChatFolderOptionInteger(response);
        if (value) {
            [limits setObject:value forKey:name];
        } else if (!firstError && optionError) {
            firstError = optionError;
        }
    }
    if ([limits count] == 0 && error) {
        *error = firstError ? firstError : [self errorWithDescription:@"The loaded TDLib did not publish chat-folder limits." code:376];
    }
    return limits;
}

@end
