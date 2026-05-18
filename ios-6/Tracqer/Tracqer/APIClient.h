@class VinylRecord;
@class Photo;

extern NSString * const TracqerAPIErrorDomain;

typedef void (^APIVoidCompletion)(BOOL ok, NSError *error);
typedef void (^APIRecordCompletion)(VinylRecord *record, NSError *error);
typedef void (^APIRecordListCompletion)(NSArray *records, NSInteger total, NSError *error);
typedef void (^APIDataCompletion)(NSData *data, NSError *error);

@interface APIClient : NSObject

@property (copy,   nonatomic, readonly) NSString *baseURL;
@property (strong, nonatomic, readonly) NSData *key;
@property (copy,   nonatomic, readonly) NSString *token;

+ (instancetype)sharedClient;
+ (void)configureSharedWithBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token;
+ (void)resetShared;

- (instancetype)initWithBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token;

// Unencrypted health check (GET /ping). Returns YES if status 200.
+ (void)pingBaseURL:(NSString *)baseURL completion:(APIVoidCompletion)completion;

// Encrypted /api/v1/auth/verify round-trip. Returns YES if server returns {"valid": true}.
+ (void)verifyBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token completion:(APIVoidCompletion)completion;

// CRUD
- (void)listRecordsSearch:(NSString *)search page:(NSInteger)page limit:(NSInteger)limit completion:(APIRecordListCompletion)completion;
- (void)getRecord:(NSString *)recordId completion:(APIRecordCompletion)completion;
- (void)createRecord:(VinylRecord *)record completion:(APIRecordCompletion)completion;
- (void)updateRecord:(VinylRecord *)record completion:(APIRecordCompletion)completion;
- (void)deleteRecord:(NSString *)recordId completion:(APIVoidCompletion)completion;

// Photo URL (server expects ?token=…&size=…). size in {240, 320, 640, 1280}.
- (NSURL *)photoURLForRecord:(NSString *)recordId photo:(Photo *)photo size:(NSInteger)size;

// Fetch photo binary data (JPEG thumbnail bytes). Caches in memory.
- (void)fetchPhotoData:(NSURL *)url completion:(APIDataCompletion)completion;

@end
