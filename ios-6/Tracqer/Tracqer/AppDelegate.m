#import "AppDelegate.h"
#import "APIClient.h"
#import "Constants.h"
#import "Crypto.h"
#import "CryptoParityTest.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

#if DEBUG
    [CryptoParityTest runWithLogging];
#endif

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *url     = [d stringForKey:kTracqerDefaultsKeyServerURL];
    NSString *keyB64  = [d stringForKey:kTracqerDefaultsKeyAESKey];
    NSString *token   = [d stringForKey:kTracqerDefaultsKeyAuthToken];

    if (url.length && keyB64.length && token.length) {
        NSData *key = [Crypto dataFromBase64String:keyB64];
        [APIClient configureSharedWithBaseURL:url key:key token:token];
        self.window.rootViewController = [self makeMainTabBarController];
    } else {
        self.window.rootViewController = [self makeLoginRoot];
    }

    [self.window makeKeyAndVisible];
    return YES;
}

- (UIViewController *)makeLoginRoot {
    LoginViewController *login = [[LoginViewController alloc] init];
    login.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:login];
    return nav;
}

- (UIViewController *)makeMainTabBarController {
    MainTabBarController *tabs = [[MainTabBarController alloc] init];
    tabs.sessionDelegate = self;
    return tabs;
}

#pragma mark - Login / logout transitions

- (void)loginViewControllerDidLogIn:(LoginViewController *)sender {
    self.window.rootViewController = [self makeMainTabBarController];
}

- (void)mainTabBarControllerDidRequestLogout:(MainTabBarController *)sender {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:kTracqerDefaultsKeyServerURL];
    [d removeObjectForKey:kTracqerDefaultsKeyAESKey];
    [d removeObjectForKey:kTracqerDefaultsKeyAuthToken];
    [d synchronize];
    [APIClient resetShared];
    self.window.rootViewController = [self makeLoginRoot];
}

@end
