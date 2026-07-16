#import "TGUpdateSupport.h"

static NSString * const TGUpdateAPIURLString = @"https://api.github.com/repos/MiChiRose/telegraphica/releases?per_page=10";
static NSString * const TGProjectReleasesURLString = @"https://github.com/MiChiRose/telegraphica/releases";

NSString *TGCurrentApplicationVersionString(void) {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if ([version length] == 0) {
        version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    }
    return ([version length] > 0) ? version : @"0.0.0";
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
        if ([draft respondsToSelector:@selector(boolValue)] && [draft boolValue]) {
            continue;
        }
        id tagNameObject = [release objectForKey:@"tag_name"];
        id nameObject = [release objectForKey:@"name"];
        NSString *tagName = [tagNameObject isKindOfClass:[NSString class]] ? tagNameObject : nil;
        NSString *name = [nameObject isKindOfClass:[NSString class]] ? nameObject : nil;
        NSString *version = ([tagName length] > 0) ? tagName : name;
        if ([version length] == 0) {
            continue;
        }
        id htmlURLObject = [release objectForKey:@"html_url"];
        NSString *htmlURL = [htmlURLObject isKindOfClass:[NSString class]] ? htmlURLObject : nil;
        if ([htmlURL length] == 0) {
            htmlURL = TGProjectReleasesURLString;
        }
        return [NSDictionary dictionaryWithObjectsAndKeys:
                version, @"version",
                htmlURL, @"url",
                nil];
    }

    if (error) {
        *error = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                     code:3
                                 userInfo:[NSDictionary dictionaryWithObject:@"No GitHub releases were found." forKey:NSLocalizedDescriptionKey]];
    }
    return nil;
}
