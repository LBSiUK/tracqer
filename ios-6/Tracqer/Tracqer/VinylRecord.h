@interface Photo : NSObject

@property (copy,   nonatomic) NSString *photoId;
@property (copy,   nonatomic) NSString *photoType;     // e.g. "sleeve_front", "disc_front"
@property (strong, nonatomic) NSNumber *discNumber;    // nil for sleeve photos
@property (copy,   nonatomic) NSString *mimeType;
@property (assign, nonatomic) NSInteger fileSize;
@property (copy,   nonatomic) NSString *createdAt;

+ (instancetype)photoFromDictionary:(NSDictionary *)dict;
- (BOOL)isDiscPhoto;
- (NSString *)displayLabel;

@end

#pragma mark -

@interface VinylRecord : NSObject

@property (copy, nonatomic) NSString *recordId;
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *artist;
@property (strong, nonatomic) NSNumber *year;
@property (copy, nonatomic) NSString *duration;
@property (copy, nonatomic) NSString *label;
@property (copy, nonatomic) NSString *format;
@property (copy, nonatomic) NSString *speed;
@property (copy, nonatomic) NSString *genre;
@property (copy, nonatomic) NSString *notes;
@property (copy, nonatomic) NSString *owner;
@property (assign, nonatomic) NSInteger discCount;
@property (assign, nonatomic) BOOL outerSleeveOnly;
@property (copy, nonatomic) NSString *discCondition;
@property (copy, nonatomic) NSString *sleeveCondition;
@property (copy, nonatomic) NSString *createdAt;
@property (copy, nonatomic) NSString *updatedAt;
@property (copy, nonatomic) NSArray *photos;           // array of Photo

+ (instancetype)recordFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionaryForInput;

@end
