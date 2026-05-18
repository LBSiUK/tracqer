typedef NS_ENUM(NSInteger, RecordListFilter) {
    RecordListFilterAll,
    RecordListFilterLPs,
    RecordListFilterSingles,
};

@interface RecordListViewController : UITableViewController <UISearchBarDelegate>

@property (assign, nonatomic) RecordListFilter filter;

- (instancetype)initWithFilter:(RecordListFilter)filter;
- (void)reload;

@end
