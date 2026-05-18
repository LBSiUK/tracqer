@protocol MainTabBarControllerDelegate;

@interface MainTabBarController : UITabBarController
@property (weak, nonatomic) id<MainTabBarControllerDelegate> sessionDelegate;
@end

@protocol MainTabBarControllerDelegate <NSObject>
- (void)mainTabBarControllerDidRequestLogout:(MainTabBarController *)sender;
@end
