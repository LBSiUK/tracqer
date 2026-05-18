#import "RecordListViewController.h"
#import "RecordDetailViewController.h"
#import "APIClient.h"
#import "VinylRecord.h"

@interface RecordListViewController ()
@property (strong, nonatomic) NSArray *allRecords;       // raw fetched records
@property (strong, nonatomic) NSArray *displayedRecords; // after filter + search
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UIRefreshControl *refresh;
@property (copy, nonatomic) NSString *searchTerm;
@end

@implementation RecordListViewController

- (instancetype)initWithFilter:(RecordListFilter)filter {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _filter = filter;
        _allRecords = @[];
        _displayedRecords = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
    self.searchBar.placeholder = @"Search title or artist";
    self.searchBar.delegate = self;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tableView.tableHeaderView = self.searchBar;

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = self.refresh;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.allRecords.count == 0) [self reload];
}

#pragma mark - Loading

- (void)reload {
    APIClient *client = [APIClient sharedClient];
    if (!client) return;

    [self.refresh beginRefreshing];
    [client listRecordsSearch:self.searchTerm page:1 limit:200 completion:^(NSArray *records, NSInteger total, NSError *err) {
        [self.refresh endRefreshing];
        if (err) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Could not load records"
                                                        message:err.localizedDescription
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
            [a show];
            return;
        }
        self.allRecords = records ?: @[];
        [self applyFilterAndReload];
    }];
}

- (void)applyFilterAndReload {
    NSPredicate *p = nil;
    switch (self.filter) {
        case RecordListFilterLPs:
            p = [NSPredicate predicateWithBlock:^BOOL(VinylRecord *r, NSDictionary *_) {
                return r.format != nil && [r.format rangeOfString:@"LP"].location != NSNotFound;
            }];
            break;
        case RecordListFilterSingles:
            p = [NSPredicate predicateWithBlock:^BOOL(VinylRecord *r, NSDictionary *_) {
                return r.format != nil && [r.format rangeOfString:@"single"].location != NSNotFound;
            }];
            break;
        default: break;
    }
    self.displayedRecords = p ? [self.allRecords filteredArrayUsingPredicate:p] : self.allRecords;
    [self.tableView reloadData];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.displayedRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"r";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];

    VinylRecord *r = self.displayedRecords[indexPath.row];
    cell.textLabel.text = r.title.length ? r.title : @"(untitled)";
    NSMutableString *sub = [NSMutableString stringWithString:r.artist ?: @""];
    NSMutableArray *trailing = [NSMutableArray array];
    if (r.format)       [trailing addObject:r.format];
    if (r.year)         [trailing addObject:[r.year stringValue]];
    if (trailing.count) [sub appendFormat:@" · %@", [trailing componentsJoinedByString:@" · "]];
    cell.detailTextLabel.text = sub;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    VinylRecord *r = self.displayedRecords[indexPath.row];
    RecordDetailViewController *detail = [[RecordDetailViewController alloc] initWithRecord:r];
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark - Delete

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    VinylRecord *r = self.displayedRecords[indexPath.row];
    [[APIClient sharedClient] deleteRecord:r.recordId completion:^(BOOL ok, NSError *err) {
        if (!ok) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Delete failed"
                                                        message:err.localizedDescription
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        NSMutableArray *all = [self.allRecords mutableCopy];
        [all removeObject:r];
        self.allRecords = all;
        [self applyFilterAndReload];
    }];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchTerm = searchText;
    // Server-side search; debounce by reloading on a delay.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload) object:nil];
    [self performSelector:@selector(reload) withObject:nil afterDelay:0.4];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self reload];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.searchTerm = nil;
    [searchBar resignFirstResponder];
    [self reload];
}

@end
