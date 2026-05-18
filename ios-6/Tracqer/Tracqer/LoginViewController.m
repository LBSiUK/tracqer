#import "LoginViewController.h"
#import "APIClient.h"
#import "Crypto.h"
#import "Constants.h"

@interface LoginViewController ()
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UITextField *urlField;
@property (strong, nonatomic) UITextField *passwordField;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@property (strong, nonatomic) UIBarButtonItem *connectButton;
@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tracqer";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    self.connectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect"
                                                          style:UIBarButtonItemStyleDone
                                                         target:self
                                                         action:@selector(connectTapped)];
    self.navigationItem.rightBarButtonItem = self.connectButton;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    self.urlField = [self makeFieldWithPlaceholder:@"https://server.example.com" secure:NO];
    // UIKeyboardTypeURL on iOS 6 hides the colon — using ASCIICapable so users can reach `:` via the 123 layer.
    self.urlField.keyboardType = UIKeyboardTypeASCIICapable;
    self.urlField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.urlField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.urlField.returnKeyType = UIReturnKeyNext;
    self.urlField.text = [[NSUserDefaults standardUserDefaults] stringForKey:kTracqerDefaultsKeyServerURL];

    self.passwordField = [self makeFieldWithPlaceholder:@"Password" secure:YES];
    self.passwordField.returnKeyType = UIReturnKeyGo;
}

- (UITextField *)makeFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectZero];
    f.placeholder = placeholder;
    f.secureTextEntry = secure;
    f.font = [UIFont systemFontOfSize:17];
    f.delegate = self;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    return f;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.urlField.text.length == 0) [self.urlField becomeFirstResponder];
    else [self.passwordField becomeFirstResponder];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Server URL" : @"Password";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"f";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];

    UITextField *f = (indexPath.section == 0) ? self.urlField : self.passwordField;
    CGFloat cellH = tableView.rowHeight > 0 ? tableView.rowHeight : 44;
    CGFloat fieldH = 30;
    f.frame = CGRectMake(15, (cellH - fieldH) / 2, cell.contentView.bounds.size.width - 30, fieldH);
    f.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:f];
    return cell;
}

#pragma mark - UITextField

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.urlField) {
        [self.passwordField becomeFirstResponder];
    } else {
        [self connectTapped];
    }
    return NO;
}

#pragma mark - Connect

- (void)connectTapped {
    NSString *url = [self.urlField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *pwd = self.passwordField.text ?: @"";

    if (url.length == 0 || pwd.length == 0) {
        [self showAlertWithTitle:@"Missing details" message:@"Enter both server URL and password."];
        return;
    }

    [self setBusy:YES];

    [APIClient pingBaseURL:url completion:^(BOOL ok, NSError *pingErr) {
        if (!ok) {
            [self setBusy:NO];
            [self showAlertWithTitle:@"Server unreachable"
                             message:pingErr.localizedDescription ?: @"Could not reach the server."];
            return;
        }

        NSData *key = [Crypto deriveKeyFromPassword:pwd];
        NSString *token = [Crypto tokenFromKey:key];

        [APIClient verifyBaseURL:url key:key token:token completion:^(BOOL valid, NSError *verifyErr) {
            [self setBusy:NO];
            if (!valid) {
                [self showAlertWithTitle:@"Login failed"
                                 message:verifyErr.localizedDescription ?: @"Wrong password."];
                return;
            }
            NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
            [d setObject:url                                   forKey:kTracqerDefaultsKeyServerURL];
            [d setObject:[Crypto base64StringFromData:key] forKey:kTracqerDefaultsKeyAESKey];
            [d setObject:token                                 forKey:kTracqerDefaultsKeyAuthToken];
            [d synchronize];

            [APIClient configureSharedWithBaseURL:url key:key token:token];
            [self.delegate loginViewControllerDidLogIn:self];
        }];
    }];
}

- (void)setBusy:(BOOL)busy {
    self.connectButton.enabled = !busy;
    self.urlField.enabled = !busy;
    self.passwordField.enabled = !busy;
    if (busy) {
        UIBarButtonItem *spin = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
        [self.spinner startAnimating];
        self.navigationItem.rightBarButtonItem = spin;
    } else {
        [self.spinner stopAnimating];
        self.navigationItem.rightBarButtonItem = self.connectButton;
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)msg {
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

@end
