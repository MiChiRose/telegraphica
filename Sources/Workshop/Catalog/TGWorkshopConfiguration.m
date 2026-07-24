#import "TGWorkshopConfiguration.h"

static NSString * const TGWorkshopDefaultCatalogURLString =
    @"https://telegraphica-tdlib-config.telegraphica.workers.dev/v1/workshop/catalog";
static NSString * const TGWorkshopCatalogURLDefaultsKey = @"TelegraphicaWorkshopCatalogURL";

NSString *TGWorkshopCatalogURLString(void) {
    NSString *override = [[NSUserDefaults standardUserDefaults] stringForKey:TGWorkshopCatalogURLDefaultsKey];
    return ([override length] > 0) ? override : TGWorkshopDefaultCatalogURLString;
}

NSURL *TGWorkshopCatalogURL(void) {
    return [NSURL URLWithString:TGWorkshopCatalogURLString()];
}

NSSet *TGWorkshopAllowedDownloadHosts(void) {
    return [NSSet setWithObjects:
            @"telegraphica-tdlib-config.telegraphica.workers.dev",
            @"github.com",
            @"objects.githubusercontent.com",
            @"github-releases.githubusercontent.com",
            nil];
}

NSString *TGWorkshopBundledCatalogPath(void) {
    return [[NSBundle mainBundle] pathForResource:@"WorkshopCatalog" ofType:@"json"];
}

static NSDictionary *TGWorkshopCertificatePaths(NSString *catalogResource, NSString *packageResource) {
    NSMutableDictionary *paths = [NSMutableDictionary dictionary];
    NSString *catalogPath = [[NSBundle mainBundle] pathForResource:catalogResource ofType:@"der"];
    NSString *packagePath = [[NSBundle mainBundle] pathForResource:packageResource ofType:@"der"];
    if ([catalogPath length] > 0) {
        [paths setObject:catalogPath forKey:@"catalog-2026-01"];
    }
    if ([packagePath length] > 0) {
        [paths setObject:packagePath forKey:@"package-2026-01"];
    }
    return paths;
}

NSDictionary *TGWorkshopCatalogCertificatePaths(void) {
    return TGWorkshopCertificatePaths(@"WorkshopCatalogPublicKey", @"UnusedWorkshopPackageKey");
}

NSDictionary *TGWorkshopPackageCertificatePaths(void) {
    return TGWorkshopCertificatePaths(@"UnusedWorkshopCatalogKey", @"WorkshopPackagePublicKey");
}
