#import "TGUpdateSupport.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const TGUpdateAPIURLString = @"https://api.github.com/repos/MiChiRose/telegraphica/releases?per_page=10";
static NSString * const TGUpdateManifestURLStringValue = @"https://telegraphica-tdlib-config.telegraphica.workers.dev/v1/update-manifest?platform=macos&channel=beta";
static NSString * const TGUpdateManifestURLDefaultsKey = @"TelegraphicaUpdateManifestURL";
static NSString * const TGProjectReleasesURLString = @"https://github.com/MiChiRose/telegraphica/releases";

static NSString *TGUpdateStringValue(id object) {
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

static BOOL TGUpdateBoolValue(id object) {
    return [object respondsToSelector:@selector(boolValue)] ? [object boolValue] : NO;
}

static NSDictionary *TGUpdatePreferredAssetFromAssets(NSArray *assets) {
    NSDictionary *preferredDMG = nil;
    NSDictionary *preferredZIP = nil;
    NSUInteger index = 0;
    for (index = 0; index < [assets count]; index++) {
        id assetObject = [assets objectAtIndex:index];
        if (![assetObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *asset = (NSDictionary *)assetObject;
        NSString *name = TGUpdateStringValue([asset objectForKey:@"name"]);
        NSString *url = TGUpdateStringValue([asset objectForKey:@"browser_download_url"]);
        if ([url length] == 0) {
            url = TGUpdateStringValue([asset objectForKey:@"download_url"]);
        }
        if ([name length] == 0 || [url length] == 0) {
            continue;
        }
        NSString *lower = [name lowercaseString];
        if ([lower hasSuffix:@".dmg"]) {
            preferredDMG = asset;
            break;
        }
        if ([lower hasSuffix:@".zip"] && ![lower hasSuffix:@".sha256"]) {
            preferredZIP = asset;
        }
    }
    return preferredDMG ? preferredDMG : preferredZIP;
}

static NSString *TGUpdateSHA256ForAssetName(NSArray *assets, NSString *assetName) {
    if ([assetName length] == 0) {
        return nil;
    }
    NSString *assetBase = [[assetName stringByDeletingPathExtension] lowercaseString];
    NSUInteger index = 0;
    for (index = 0; index < [assets count]; index++) {
        id assetObject = [assets objectAtIndex:index];
        if (![assetObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *asset = (NSDictionary *)assetObject;
        NSString *name = TGUpdateStringValue([asset objectForKey:@"name"]);
        NSString *sha = TGUpdateStringValue([asset objectForKey:@"sha256"]);
        NSString *lowerName = [name lowercaseString];
        if ([sha length] == 64 && ([lowerName hasPrefix:assetBase] || [lowerName rangeOfString:assetBase].location != NSNotFound)) {
            return sha;
        }
    }
    return nil;
}

static NSDictionary *TGUpdateInfoFromReleaseDictionary(NSDictionary *release, NSString *source) {
    NSString *tagName = TGUpdateStringValue([release objectForKey:@"tag_name"]);
    NSString *name = TGUpdateStringValue([release objectForKey:@"name"]);
    NSString *version = ([tagName length] > 0) ? tagName : name;
    if ([version length] == 0) {
        return nil;
    }

    NSString *htmlURL = TGUpdateStringValue([release objectForKey:@"html_url"]);
    if ([htmlURL length] == 0) {
        htmlURL = TGUpdateStringValue([release objectForKey:@"release_url"]);
    }
    if ([htmlURL length] == 0) {
        htmlURL = TGProjectReleasesURLString;
    }

    NSArray *assets = [[release objectForKey:@"assets"] isKindOfClass:[NSArray class]] ? [release objectForKey:@"assets"] : nil;
    NSDictionary *asset = TGUpdatePreferredAssetFromAssets(assets);
    NSString *downloadURL = TGUpdateStringValue([release objectForKey:@"download_url"]);
    NSString *fileName = TGUpdateStringValue([release objectForKey:@"file_name"]);
    NSString *sha256 = TGUpdateStringValue([release objectForKey:@"sha256"]);
    if ([downloadURL length] == 0 && asset) {
        downloadURL = TGUpdateStringValue([asset objectForKey:@"browser_download_url"]);
        if ([downloadURL length] == 0) {
            downloadURL = TGUpdateStringValue([asset objectForKey:@"download_url"]);
        }
    }
    if ([fileName length] == 0 && asset) {
        fileName = TGUpdateStringValue([asset objectForKey:@"name"]);
    }
    if ([sha256 length] == 0 && [assets count] > 0) {
        sha256 = TGUpdateSHA256ForAssetName(assets, fileName);
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 version, @"version",
                                 htmlURL, @"url",
                                 source ? source : @"unknown", @"source",
                                 nil];
    if ([downloadURL length] > 0) {
        [info setObject:downloadURL forKey:@"download_url"];
    }
    if ([fileName length] > 0) {
        [info setObject:fileName forKey:@"file_name"];
    }
    if ([sha256 length] == 64) {
        [info setObject:[sha256 lowercaseString] forKey:@"sha256"];
    }
    return info;
}

NSString *TGCurrentApplicationVersionString(void) {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if ([version length] == 0) {
        version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    }
    return ([version length] > 0) ? version : @"0.0.0";
}

BOOL TGCurrentApplicationVersionIsMountainLionBuild(void) {
    NSString *version = TGCurrentApplicationVersionString();
    return ([version isKindOfClass:[NSString class]] && [[version lowercaseString] hasSuffix:@"-ml"]);
}

NSString *TGUpdateManifestURLString(void) {
    NSString *overrideURL = [[NSUserDefaults standardUserDefaults] stringForKey:TGUpdateManifestURLDefaultsKey];
    if ([overrideURL length] > 0) {
        return overrideURL;
    }
    return TGUpdateManifestURLStringValue;
}

NSString *TGUpdateProjectReleasesURLString(void) {
    return TGProjectReleasesURLString;
}

NSURL *TGUpdateProjectReleasesURL(void) {
    return [NSURL URLWithString:TGProjectReleasesURLString];
}

NSString *TGUpdateCheckUserAgentString(void) {
    NSString *version = TGCurrentApplicationVersionString();
    if ([version length] == 0) {
        version = @"unknown";
    }
    NSString *minimumSystemVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"LSMinimumSystemVersion"];
    NSString *compatibility = [minimumSystemVersion hasPrefix:@"10.8"] ? @"Mountain-Lion-compatible" : @"Mavericks-compatible";
    return [NSString stringWithFormat:@"Telegraphica/%@ (Mac OS X; %@)", version, compatibility];
}

NSString *TGUpdateDownloadURLStringFromInfo(NSDictionary *info) {
    return [info isKindOfClass:[NSDictionary class]] ? TGUpdateStringValue([info objectForKey:@"download_url"]) : nil;
}

NSString *TGUpdateDownloadFileNameFromInfo(NSDictionary *info) {
    NSString *fileName = [info isKindOfClass:[NSDictionary class]] ? TGUpdateStringValue([info objectForKey:@"file_name"]) : nil;
    if ([fileName length] > 0) {
        return fileName;
    }
    NSString *downloadURL = TGUpdateDownloadURLStringFromInfo(info);
    NSString *lastPathComponent = [[NSURL URLWithString:downloadURL] lastPathComponent];
    return ([lastPathComponent length] > 0) ? lastPathComponent : @"Telegraphica-update.dmg";
}

BOOL TGUpdateFileMatchesSHA256(NSString *path, NSString *expectedSHA256, NSError **error) {
    if ([expectedSHA256 length] == 0) {
        return YES;
    }
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    if (!stream) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                         code:20
                                     userInfo:[NSDictionary dictionaryWithObject:@"Downloaded update file could not be opened for checksum verification." forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    [stream open];
    uint8_t buffer[32768];
    while ([stream hasBytesAvailable]) {
        NSInteger readCount = [stream read:buffer maxLength:sizeof(buffer)];
        if (readCount < 0) {
            [stream close];
            if (error) {
                *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                             code:21
                                         userInfo:[NSDictionary dictionaryWithObject:@"Downloaded update file could not be read for checksum verification." forKey:NSLocalizedDescriptionKey]];
            }
            return NO;
        }
        if (readCount > 0) {
            CC_SHA256_Update(&context, buffer, (CC_LONG)readCount);
        }
    }
    [stream close];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *actual = [NSMutableString stringWithCapacity:(CC_SHA256_DIGEST_LENGTH * 2)];
    NSUInteger index = 0;
    for (index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [actual appendFormat:@"%02x", digest[index]];
    }
    BOOL matches = [[actual lowercaseString] isEqualToString:[expectedSHA256 lowercaseString]];
    if (!matches && error) {
        *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                     code:22
                                 userInfo:[NSDictionary dictionaryWithObject:@"Downloaded update checksum does not match the release manifest." forKey:NSLocalizedDescriptionKey]];
    }
    return matches;
}

NSString *TGGitHubErrorMessageFromData(NSData *data, NSString *fallback) {
    if ([data length] == 0) {
        return fallback;
    }
    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if ([object isKindOfClass:[NSDictionary class]]) {
        id messageObject = [(NSDictionary *)object objectForKey:@"message"];
        NSString *message = [messageObject isKindOfClass:[NSString class]] ? messageObject : nil;
        if ([message length] > 0) {
            return message;
        }
    }
    return fallback;
}

static NSDictionary *TGLatestManifestReleaseInfoWithError(NSError **error) {
    NSURL *url = [NSURL URLWithString:TGUpdateManifestURLString()];
    if (!url) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                         code:10
                                     userInfo:[NSDictionary dictionaryWithObject:@"Update manifest URL is invalid." forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:12.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:TGUpdateCheckUserAgentString() forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
    if (![data isKindOfClass:[NSData class]] || [data length] == 0) {
        return nil;
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode < 200 || statusCode >= 300) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Update manifest returned HTTP %ld.", (long)statusCode];
                *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                             code:statusCode
                                         userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
            }
            return nil;
        }
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                         code:11
                                     userInfo:[NSDictionary dictionaryWithObject:@"Update manifest did not return an object." forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    NSDictionary *info = TGUpdateInfoFromReleaseDictionary((NSDictionary *)json, @"cloudflare");
    if (!info && error) {
        *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                     code:12
                                 userInfo:[NSDictionary dictionaryWithObject:@"Update manifest does not contain a release version." forKey:NSLocalizedDescriptionKey]];
    }
    return info;
}

NSDictionary *TGLatestGitHubReleaseInfoWithError(NSError **error) {
    NSURL *url = [NSURL URLWithString:TGUpdateAPIURLString];
    if (!url) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                         code:1
                                     userInfo:[NSDictionary dictionaryWithObject:@"Update URL is invalid." forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:18.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:TGUpdateCheckUserAgentString() forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:error];
    if (![data isKindOfClass:[NSData class]] || [data length] == 0) {
        return nil;
    }

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode < 200 || statusCode >= 300) {
            if (error) {
                NSString *fallback = [NSString stringWithFormat:@"GitHub returned HTTP %ld.", (long)statusCode];
                NSString *message = TGGitHubErrorMessageFromData(data, fallback);
                *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                             code:statusCode
                                         userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
            }
            return nil;
        }
    }

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                         code:2
                                     userInfo:[NSDictionary dictionaryWithObject:@"GitHub did not return a release list." forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSArray *releases = (NSArray *)json;
    NSUInteger index = 0;
    for (index = 0; index < [releases count]; index++) {
        id releaseObject = [releases objectAtIndex:index];
        if (![releaseObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *release = (NSDictionary *)releaseObject;
        id draft = [release objectForKey:@"draft"];
        if (TGUpdateBoolValue(draft)) {
            continue;
        }
        NSDictionary *info = TGUpdateInfoFromReleaseDictionary(release, @"github");
        if (!info) {
            continue;
        }
        return info;
    }

    if (error) {
        *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                     code:3
                                 userInfo:[NSDictionary dictionaryWithObject:@"No GitHub releases were found." forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}

NSDictionary *TGLatestUpdateInfoWithError(NSError **error) {
    NSError *manifestError = nil;
    NSDictionary *manifestInfo = TGLatestManifestReleaseInfoWithError(&manifestError);
    if (manifestInfo) {
        return manifestInfo;
    }

    if (error) {
        NSString *message = [manifestError localizedDescription];
        if ([message length] == 0) {
            message = @"Update manifest did not return release information.";
        }
        *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                     code:13
                                 userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}
