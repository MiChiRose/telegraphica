#import <Foundation/Foundation.h>

NSString *TGCurrentApplicationVersionString(void);
NSString *TGUpdateManifestURLString(void);
NSString *TGUpdateProjectReleasesURLString(void);
NSURL *TGUpdateProjectReleasesURL(void);
NSString *TGUpdateCheckUserAgentString(void);
NSString *TGGitHubErrorMessageFromData(NSData *data, NSString *fallback);
NSDictionary *TGLatestGitHubReleaseInfoWithError(NSError **error);
NSDictionary *TGLatestUpdateInfoWithError(NSError **error);
NSString *TGUpdateDownloadURLStringFromInfo(NSDictionary *info);
NSString *TGUpdateDownloadFileNameFromInfo(NSDictionary *info);
BOOL TGUpdateFileMatchesSHA256(NSString *path, NSString *expectedSHA256, NSError **error);
