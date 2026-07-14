#import <Foundation/Foundation.h>

NSString *TGCurrentApplicationVersionString(void);
NSString *TGUpdateProjectReleasesURLString(void);
NSURL *TGUpdateProjectReleasesURL(void);
NSString *TGUpdateCheckUserAgentString(void);
NSString *TGGitHubErrorMessageFromData(NSData *data, NSString *fallback);
NSDictionary *TGLatestGitHubReleaseInfoWithError(NSError **error);
