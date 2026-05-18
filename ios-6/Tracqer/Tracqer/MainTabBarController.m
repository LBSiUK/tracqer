#import "MainTabBarController.h"
#import "RecordListViewController.h"
#import "APIClient.h"

#pragma mark - Tab icons (drawn programmatically — iOS 6 tints them automatically)

// All icons are 30×30pt alpha masks. iOS 6 renders them in the standard
// blue/grey tab bar gradient based on selected state.

static UIImage *MakeIcon(void (^draw)(CGContextRef ctx, CGRect r)) {
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setFill];
    [[UIColor blackColor] setStroke];
    draw(ctx, CGRectMake(0, 0, size.width, size.height));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static UIImage *AllListIcon(void) {
    return MakeIcon(^(CGContextRef ctx, CGRect r) {
        // Three horizontal bars, each with a small bullet on the left
        CGFloat barH = 3, gap = 5, leftPad = 4, bulletR = 1.5;
        for (int i = 0; i < 3; i++) {
            CGFloat y = 6 + i * (barH + gap);
            CGContextFillEllipseInRect(ctx, CGRectMake(leftPad, y + barH/2 - bulletR, bulletR * 2, bulletR * 2));
            CGContextFillRect(ctx, CGRectMake(leftPad + 6, y, r.size.width - leftPad - 8, barH));
        }
    });
}

static UIImage *RecordIcon(CGFloat outerR, CGFloat innerR) {
    return MakeIcon(^(CGContextRef ctx, CGRect r) {
        CGPoint c = CGPointMake(r.size.width / 2, r.size.height / 2);
        // outer disc
        CGContextFillEllipseInRect(ctx, CGRectMake(c.x - outerR, c.y - outerR, outerR * 2, outerR * 2));
        // groove ring (cut out)
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        CGFloat groove = outerR * 0.55;
        CGContextStrokeEllipseInRect(ctx, CGRectMake(c.x - groove, c.y - groove, groove * 2, groove * 2));
        // center hole
        CGContextFillEllipseInRect(ctx, CGRectMake(c.x - innerR, c.y - innerR, innerR * 2, innerR * 2));
        CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    });
}

static UIImage *LPIcon(void)       { return RecordIcon(13, 2.5); }
static UIImage *SingleIcon(void)   { return RecordIcon(10, 2.0); }

static UIImage *SearchIcon(void) {
    return MakeIcon(^(CGContextRef ctx, CGRect r) {
        CGFloat lensR = 6;
        CGPoint lensC = CGPointMake(11, 11);
        CGContextSetLineWidth(ctx, 2);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(lensC.x - lensR, lensC.y - lensR, lensR * 2, lensR * 2));
        CGContextMoveToPoint(ctx, lensC.x + lensR * 0.7, lensC.y + lensR * 0.7);
        CGContextAddLineToPoint(ctx, lensC.x + lensR * 0.7 + 9, lensC.y + lensR * 0.7 + 9);
        CGContextStrokePath(ctx);
    });
}

static UIImage *SettingsIcon(void) {
    return MakeIcon(^(CGContextRef ctx, CGRect r) {
        // Three horizontal sliders, evoking settings/EQ
        CGFloat lineY[3] = {8, 15, 22};
        CGFloat knobX[3] = {18, 8, 21};
        CGContextSetLineWidth(ctx, 2);
        for (int i = 0; i < 3; i++) {
            CGContextMoveToPoint(ctx, 3, lineY[i]);
            CGContextAddLineToPoint(ctx, 27, lineY[i]);
            CGContextStrokePath(ctx);
            CGContextFillEllipseInRect(ctx, CGRectMake(knobX[i] - 3, lineY[i] - 3, 6, 6));
        }
    });
}

#pragma mark - Build date helper (mtime of the executable, formatted UTC)

static NSString *BuildDateStringUTC(void) {
    NSString *path = [[NSBundle mainBundle] executablePath];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    NSDate *date = attrs[NSFileModificationDate];
    if (!date) return @"";
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale     = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    fmt.dateFormat = @"HH:mm, d MMM yyyy 'UTC'";
    return [fmt stringFromDate:date];
}

#pragma mark - Placeholder for Search + Settings tabs

@interface PlaceholderViewController : UIViewController
@property (copy, nonatomic) NSString *message;
@property (weak, nonatomic) MainTabBarController *parentTabBar;
@property (assign, nonatomic) BOOL hasLogoutButton;
@end

@implementation PlaceholderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 80)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    l.text = self.message;
    l.font = [UIFont systemFontOfSize:17];
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    l.textColor = [UIColor darkGrayColor];
    [self.view addSubview:l];

    if (self.hasLogoutButton) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Log out"
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logoutTapped)];

        // Footer: "Tracqer vX.Y (HH:mm, D MMM YYYY UTC) / Made with ❤️ in London and Brighton / by Leon Brahams"
        CGFloat w = self.view.bounds.size.width;
        CGFloat bottom = self.view.bounds.size.height - 80;

        NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
        UILabel *buildLine = [[UILabel alloc] initWithFrame:CGRectMake(20, bottom, w - 40, 14)];
        buildLine.text = [NSString stringWithFormat:@"Tracqer v%@ (%@)", v, BuildDateStringUTC()];
        buildLine.font = [UIFont systemFontOfSize:11];
        buildLine.textAlignment = NSTextAlignmentCenter;
        buildLine.textColor = [UIColor lightGrayColor];
        buildLine.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

        UILabel *credit1 = [[UILabel alloc] initWithFrame:CGRectMake(20, bottom + 20, w - 40, 18)];
        credit1.text = @"Made with ❤️ in London and Brighton";
        credit1.font = [UIFont systemFontOfSize:13];
        credit1.textAlignment = NSTextAlignmentCenter;
        credit1.textColor = [UIColor grayColor];
        credit1.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

        UILabel *credit2 = [[UILabel alloc] initWithFrame:CGRectMake(20, bottom + 40, w - 40, 18)];
        credit2.text = @"by Leon Brahams";
        credit2.font = [UIFont systemFontOfSize:13];
        credit2.textAlignment = NSTextAlignmentCenter;
        credit2.textColor = [UIColor grayColor];
        credit2.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

        [self.view addSubview:buildLine];
        [self.view addSubview:credit1];
        [self.view addSubview:credit2];
    }
}

- (void)logoutTapped {
    [self.parentTabBar.sessionDelegate mainTabBarControllerDidRequestLogout:self.parentTabBar];
}

@end

#pragma mark -

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSMutableArray *navs = [NSMutableArray array];

    [navs addObject:[self navWithList:RecordListFilterAll     title:@"All"     icon:AllListIcon()]];
    [navs addObject:[self navWithList:RecordListFilterLPs     title:@"LPs"     icon:LPIcon()]];
    [navs addObject:[self navWithList:RecordListFilterSingles title:@"Singles" icon:SingleIcon()]];

    PlaceholderViewController *search = [[PlaceholderViewController alloc] init];
    search.title = @"Search";
    search.message = @"Use the search bar at the top of any list tab.";
    search.parentTabBar = self;
    UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:search];
    searchNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search" image:SearchIcon() tag:3];
    [navs addObject:searchNav];

    PlaceholderViewController *settings = [[PlaceholderViewController alloc] init];
    settings.title = @"Settings";
    settings.message = [NSString stringWithFormat:@"Connected to:\n%@", [APIClient sharedClient].baseURL ?: @"(none)"];
    settings.hasLogoutButton = YES;
    settings.parentTabBar = self;
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settings];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:SettingsIcon() tag:4];
    [navs addObject:settingsNav];

    self.viewControllers = navs;
}

- (UINavigationController *)navWithList:(RecordListFilter)filter title:(NSString *)title icon:(UIImage *)icon {
    RecordListViewController *list = [[RecordListViewController alloc] initWithFilter:filter];
    list.title = title;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:icon tag:filter];
    return nav;
}

@end
