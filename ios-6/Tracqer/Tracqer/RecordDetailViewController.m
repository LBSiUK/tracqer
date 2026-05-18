#import "RecordDetailViewController.h"
#import "VinylRecord.h"
#import "APIClient.h"

#pragma mark - Full-screen photo viewer (private)

@interface _PhotoViewer : UIViewController <UIScrollViewDelegate>
@property (strong, nonatomic) NSURL *imageURL;
@property (copy,   nonatomic) NSString *titleText;
@property (strong, nonatomic) UIScrollView *scroll;
@property (strong, nonatomic) UIImageView  *imageView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@end

@implementation _PhotoViewer

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.titleText;
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationController.navigationBar.translucent = NO;

    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scroll.backgroundColor = [UIColor blackColor];
    self.scroll.delegate = self;
    self.scroll.minimumZoomScale = 1.0;
    self.scroll.maximumZoomScale = 4.0;
    self.scroll.showsHorizontalScrollIndicator = NO;
    self.scroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scroll];

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scroll addSubview:self.imageView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    self.spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin  | UIViewAutoresizingFlexibleBottomMargin);
    [self.spinner startAnimating];
    [self.view addSubview:self.spinner];

    [[APIClient sharedClient] fetchPhotoData:self.imageURL completion:^(NSData *data, NSError *err) {
        [self.spinner stopAnimating];
        [self.spinner removeFromSuperview];
        if (!data) return;
        UIImage *img = [UIImage imageWithData:data];
        self.imageView.image = img;
        self.imageView.frame = CGRectMake(0, 0, self.scroll.bounds.size.width, self.scroll.bounds.size.height);
        self.scroll.contentSize = self.imageView.bounds.size;
    }];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView { return self.imageView; }

@end

#pragma mark - Detail row (a flat list of label/value pairs grouped into sections)

@interface DetailRow : NSObject
@property (copy, nonatomic) NSString *label;
@property (copy, nonatomic) NSString *value;
@end
@implementation DetailRow
+ (instancetype)label:(NSString *)l value:(NSString *)v {
    if (!v.length) return nil;
    DetailRow *r = [[DetailRow alloc] init];
    r.label = l; r.value = v;
    return r;
}
@end

#pragma mark -

@interface RecordDetailViewController ()
@property (strong, nonatomic) VinylRecord *record;
@property (strong, nonatomic) NSArray *sections;            // [[ {title, rows:[DetailRow]} ]]
@property (strong, nonatomic) UIScrollView *photoStrip;     // header view (or nil)
@property (strong, nonatomic) NSMutableDictionary *thumbViews; // photoId -> UIImageView
@end

@implementation RecordDetailViewController

- (instancetype)initWithRecord:(VinylRecord *)record {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _record = record;
        _thumbViews = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.record.title.length ? self.record.title : @"(untitled)";
    [self buildPhotoStrip];
    [self rebuildSections];
}

#pragma mark - Photo strip header

- (void)buildPhotoStrip {
    if (self.record.photos.count == 0) return;

    CGFloat thumbSize  = 80;
    CGFloat labelH     = 16;
    CGFloat pad        = 8;
    CGFloat stripH     = thumbSize + labelH + pad * 2;

    self.photoStrip = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, stripH)];
    self.photoStrip.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.photoStrip.showsHorizontalScrollIndicator = NO;
    self.photoStrip.alwaysBounceHorizontal = YES;

    CGFloat x = pad;
    for (Photo *photo in self.record.photos) {
        UIImageView *thumb = [[UIImageView alloc] initWithFrame:CGRectMake(x, pad, thumbSize, thumbSize)];
        thumb.contentMode = UIViewContentModeScaleAspectFill;
        thumb.clipsToBounds = YES;
        thumb.backgroundColor = [UIColor lightGrayColor];
        thumb.userInteractionEnabled = YES;
        thumb.tag = [self.record.photos indexOfObject:photo];

        UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        spin.center = CGPointMake(thumbSize / 2, thumbSize / 2);
        spin.tag = 99;
        [spin startAnimating];
        [thumb addSubview:spin];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(thumbTapped:)];
        [thumb addGestureRecognizer:tap];

        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(x, pad + thumbSize, thumbSize, labelH)];
        l.font = [UIFont systemFontOfSize:10];
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = [UIColor darkGrayColor];
        l.text = [photo displayLabel];

        [self.photoStrip addSubview:thumb];
        [self.photoStrip addSubview:l];
        self.thumbViews[photo.photoId] = thumb;

        NSURL *url = [[APIClient sharedClient] photoURLForRecord:self.record.recordId photo:photo size:240];
        [[APIClient sharedClient] fetchPhotoData:url completion:^(NSData *data, NSError *err) {
            for (UIView *v in [thumb.subviews copy]) if (v.tag == 99) [v removeFromSuperview];
            if (data) thumb.image = [UIImage imageWithData:data];
        }];

        x += thumbSize + pad;
    }
    self.photoStrip.contentSize = CGSizeMake(x, stripH);
    self.tableView.tableHeaderView = self.photoStrip;
}

- (void)thumbTapped:(UITapGestureRecognizer *)gr {
    NSUInteger idx = gr.view.tag;
    if (idx >= self.record.photos.count) return;
    Photo *photo = self.record.photos[idx];
    _PhotoViewer *viewer = [[_PhotoViewer alloc] init];
    viewer.imageURL = [[APIClient sharedClient] photoURLForRecord:self.record.recordId photo:photo size:1280];
    viewer.titleText = [photo displayLabel];
    [self.navigationController pushViewController:viewer animated:YES];
}

#pragma mark - Sections

- (void)rebuildSections {
    NSMutableArray *sections = [NSMutableArray array];

    [sections addObject:@{
        @"title": @"",
        @"rows": [self compact:@[
            [DetailRow label:@"Title"  value:self.record.title],
            [DetailRow label:@"Artist" value:self.record.artist],
        ]],
    }];

    [sections addObject:@{
        @"title": @"Format",
        @"rows": [self compact:@[
            [DetailRow label:@"Year"     value:self.record.year ? [self.record.year stringValue] : nil],
            [DetailRow label:@"Format"   value:self.record.format],
            [DetailRow label:@"Speed"    value:self.record.speed ? [NSString stringWithFormat:@"%@ rpm", self.record.speed] : nil],
            [DetailRow label:@"Duration" value:self.record.duration],
            [DetailRow label:@"Label"    value:self.record.label],
            [DetailRow label:@"Genre"    value:self.record.genre],
        ]],
    }];

    [sections addObject:@{
        @"title": @"Discs & condition",
        @"rows": [self compact:@[
            [DetailRow label:@"Discs"   value:[NSString stringWithFormat:@"%ld", (long)self.record.discCount]],
            [DetailRow label:@"Disc"    value:self.record.discCondition],
            [DetailRow label:@"Sleeve"  value:self.record.sleeveCondition],
            [DetailRow label:@"Owner"   value:self.record.owner],
        ]],
    }];

    if (self.record.notes.length) {
        [sections addObject:@{
            @"title": @"Notes",
            @"rows":  @[[DetailRow label:@"" value:self.record.notes]],
        }];
    }

    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *s in sections) if ([s[@"rows"] count] > 0) [filtered addObject:s];
    self.sections = filtered;
    [self.tableView reloadData];
}

- (NSArray *)compact:(NSArray *)rows {
    NSMutableArray *out = [NSMutableArray array];
    for (id r in rows) if (r != [NSNull null] && r != nil) [out addObject:r];
    return out;
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *t = self.sections[section][@"title"];
    return t.length ? t : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DetailRow *r = self.sections[indexPath.section][@"rows"][indexPath.row];
    BOOL isNotes = [self.sections[indexPath.section][@"title"] isEqualToString:@"Notes"];

    if (isNotes) {
        static NSString *reuse = @"notes";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
        cell.textLabel.text = r.value;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    static NSString *reuse = @"kv";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuse];
    cell.textLabel.text = r.label;
    cell.detailTextLabel.text = r.value;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isNotes = [self.sections[indexPath.section][@"title"] isEqualToString:@"Notes"];
    if (!isNotes) return 44;
    DetailRow *r = self.sections[indexPath.section][@"rows"][indexPath.row];
    CGSize size = [r.value sizeWithFont:[UIFont systemFontOfSize:15]
                      constrainedToSize:CGSizeMake(tableView.bounds.size.width - 40, CGFLOAT_MAX)
                          lineBreakMode:NSLineBreakByWordWrapping];
    return MAX(44, size.height + 20);
}

@end
