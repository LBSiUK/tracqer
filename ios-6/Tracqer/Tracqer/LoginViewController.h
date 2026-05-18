@protocol LoginViewControllerDelegate;

@interface LoginViewController : UIViewController <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) id<LoginViewControllerDelegate> delegate;

@end

@protocol LoginViewControllerDelegate <NSObject>
- (void)loginViewControllerDidLogIn:(LoginViewController *)sender;
@end
