#import "APIClient.h"
#import "Crypto.h"
#import "VinylRecord.h"

NSString * const TracqerAPIErrorDomain = @"TracqerAPI";

static APIClient *gSharedClient = nil;

static NSError *APIError(NSInteger code, NSString *msg) {
    return [NSError errorWithDomain:TracqerAPIErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg ?: @"Unknown error"}];
}

static NSString *NormaliseBaseURL(NSString *u) {
    if ([u hasSuffix:@"/"]) return [u substringToIndex:u.length - 1];
    return u;
}

static NSString *URLQueryEscape(NSString *s) {
    CFStringRef esc = CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)s, NULL,
                                                              CFSTR(":/?#[]@!$&'()*+,;="),
                                                              kCFStringEncodingUTF8);
    return CFBridgingRelease(esc);
}

#pragma mark - Internal connection wrapper (accepts any server trust)

// NSURLConnection delegate-based wrapper that accepts any TLS cert. Used because
// (a) sendAsynchronousRequest: cannot handle auth challenges, and (b) we talk
// only to the user's own server — and on the Mountain Lion build host the
// system root CA store is too old to validate modern Let's Encrypt certs.
typedef void (^TracqerHTTPCompletion)(NSURLResponse *response, NSData *data, NSError *error);

@interface _TracqerHTTPConnection : NSObject <NSURLConnectionDataDelegate> {
    NSMutableData *_buffer;
    NSURLResponse *_response;
    TracqerHTTPCompletion _completion;
    NSURLConnection *_connection;
    _TracqerHTTPConnection *_selfRetain;
}
+ (void)performRequest:(NSURLRequest *)req completion:(TracqerHTTPCompletion)completion;
@end

@implementation _TracqerHTTPConnection

+ (void)performRequest:(NSURLRequest *)req completion:(TracqerHTTPCompletion)completion {
    _TracqerHTTPConnection *c = [[self alloc] init];
    c->_buffer     = [NSMutableData data];
    c->_completion = [completion copy];
    c->_selfRetain = c;  // keep alive until connection finishes
    c->_connection = [[NSURLConnection alloc] initWithRequest:req delegate:c startImmediately:NO];
    [c->_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [c->_connection start];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *cred = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _response = response;
    _buffer.length = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_buffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (_completion) _completion(_response, [_buffer copy], nil);
    _selfRetain = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (_completion) _completion(nil, nil, error);
    _selfRetain = nil;
}

@end

#pragma mark -

@implementation APIClient

+ (instancetype)sharedClient {
    return gSharedClient;
}

+ (void)configureSharedWithBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token {
    gSharedClient = [[APIClient alloc] initWithBaseURL:baseURL key:key token:token];
}

+ (void)resetShared {
    gSharedClient = nil;
}

- (instancetype)initWithBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token {
    if ((self = [super init])) {
        _baseURL = [NormaliseBaseURL(baseURL) copy];
        _key     = [key copy];
        _token   = [token copy];
    }
    return self;
}

#pragma mark - Static endpoints (ping, verify)

+ (void)pingBaseURL:(NSString *)baseURL completion:(APIVoidCompletion)completion {
    NSString *full = [NormaliseBaseURL(baseURL) stringByAppendingString:@"/ping"];
    NSURL *url = [NSURL URLWithString:full];
    if (!url) { completion(NO, APIError(1, @"Invalid server URL")); return; }

    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:10];
    [_TracqerHTTPConnection performRequest:req completion:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err) { completion(NO, err); return; }
        NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
        if (code == 200) { completion(YES, nil); return; }
        completion(NO, APIError(code, [NSString stringWithFormat:@"Ping returned HTTP %ld", (long)code]));
    }];
}

+ (void)verifyBaseURL:(NSString *)baseURL key:(NSData *)key token:(NSString *)token completion:(APIVoidCompletion)completion {
    NSError *encErr = nil;
    NSDictionary *envelope = [Crypto encryptObject:@{} withKey:key error:&encErr];
    if (!envelope) { completion(NO, encErr ?: APIError(2, @"Encrypt failed")); return; }

    NSData *body = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:NULL];
    NSString *full = [NormaliseBaseURL(baseURL) stringByAppendingString:@"/api/v1/auth/verify"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:full]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:15];
    req.HTTPMethod = @"POST";
    req.HTTPBody = body;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];

    [_TracqerHTTPConnection performRequest:req completion:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err) { completion(NO, err); return; }
        NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
        if (code != 200) {
            completion(NO, APIError(code, [NSString stringWithFormat:@"Verify HTTP %ld", (long)code]));
            return;
        }
        id env = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![env isKindOfClass:[NSDictionary class]]) { completion(NO, APIError(3, @"Bad verify response")); return; }
        NSError *dErr = nil;
        id decrypted = [Crypto decryptEnvelope:env withKey:key error:&dErr];
        if (![decrypted isKindOfClass:[NSDictionary class]]) { completion(NO, dErr ?: APIError(4, @"Decrypt failed")); return; }
        BOOL valid = [((NSDictionary *)decrypted)[@"valid"] boolValue];
        if (valid) completion(YES, nil);
        else completion(NO, APIError(5, @"Wrong password"));
    }];
}

#pragma mark - Encrypted request core

- (void)performMethod:(NSString *)method
                 path:(NSString *)path
                 body:(id)bodyObject
           expectJSON:(BOOL)expectJSON
           completion:(void (^)(id decodedJSON, NSError *error))completion {

    NSString *full = [self.baseURL stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:full];
    if (!url) { completion(nil, APIError(1, @"Bad URL")); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:20];
    req.HTTPMethod = method;
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.token] forHTTPHeaderField:@"Authorization"];

    if (bodyObject) {
        NSError *encErr = nil;
        NSDictionary *env = [Crypto encryptObject:bodyObject withKey:self.key error:&encErr];
        if (!env) { completion(nil, encErr); return; }
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:env options:0 error:NULL];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }

    [_TracqerHTTPConnection performRequest:req completion:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
        if (code >= 300) {
            NSString *msg = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
            completion(nil, APIError(code, [NSString stringWithFormat:@"HTTP %ld: %@", (long)code, msg]));
            return;
        }
        if (!expectJSON || code == 204 || data.length == 0) {
            completion(nil, nil); return;
        }
        id env = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![env isKindOfClass:[NSDictionary class]]) { completion(nil, APIError(3, @"Bad response envelope")); return; }
        NSError *dErr = nil;
        id decrypted = [Crypto decryptEnvelope:env withKey:self.key error:&dErr];
        if (!decrypted) { completion(nil, dErr ?: APIError(4, @"Decrypt failed")); return; }
        completion(decrypted, nil);
    }];
}

#pragma mark - Records CRUD

- (void)listRecordsSearch:(NSString *)search page:(NSInteger)page limit:(NSInteger)limit completion:(APIRecordListCompletion)completion {
    NSMutableString *path = [NSMutableString stringWithFormat:@"/api/v1/records?page=%ld&limit=%ld", (long)page, (long)limit];
    if (search.length > 0) [path appendFormat:@"&search=%@", URLQueryEscape(search)];

    [self performMethod:@"GET" path:path body:nil expectJSON:YES completion:^(id json, NSError *err) {
        if (err) { completion(nil, 0, err); return; }
        NSArray *raw = json[@"records"];
        NSMutableArray *records = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSDictionary *d in raw) [records addObject:[VinylRecord recordFromDictionary:d]];
        NSInteger total = [json[@"total"] integerValue];
        completion(records, total, nil);
    }];
}

- (void)getRecord:(NSString *)recordId completion:(APIRecordCompletion)completion {
    [self performMethod:@"GET" path:[NSString stringWithFormat:@"/api/v1/records/%@", recordId] body:nil expectJSON:YES completion:^(id json, NSError *err) {
        if (err) { completion(nil, err); return; }
        completion([VinylRecord recordFromDictionary:json], nil);
    }];
}

- (void)createRecord:(VinylRecord *)record completion:(APIRecordCompletion)completion {
    [self performMethod:@"POST" path:@"/api/v1/records" body:[record toDictionaryForInput] expectJSON:YES completion:^(id json, NSError *err) {
        if (err) { completion(nil, err); return; }
        completion([VinylRecord recordFromDictionary:json], nil);
    }];
}

- (void)updateRecord:(VinylRecord *)record completion:(APIRecordCompletion)completion {
    NSString *path = [NSString stringWithFormat:@"/api/v1/records/%@", record.recordId];
    [self performMethod:@"PATCH" path:path body:[record toDictionaryForInput] expectJSON:YES completion:^(id json, NSError *err) {
        if (err) { completion(nil, err); return; }
        completion([VinylRecord recordFromDictionary:json], nil);
    }];
}

- (void)deleteRecord:(NSString *)recordId completion:(APIVoidCompletion)completion {
    NSString *path = [NSString stringWithFormat:@"/api/v1/records/%@", recordId];
    [self performMethod:@"DELETE" path:path body:nil expectJSON:NO completion:^(id json, NSError *err) {
        completion(err == nil, err);
    }];
}

#pragma mark - Photos (read-only)

- (NSURL *)photoURLForRecord:(NSString *)recordId photo:(Photo *)photo size:(NSInteger)size {
    NSString *path;
    if ([photo isDiscPhoto] && photo.discNumber) {
        path = [NSString stringWithFormat:@"/api/v1/records/%@/photos/%@/%@", recordId, photo.photoType, photo.discNumber];
    } else {
        path = [NSString stringWithFormat:@"/api/v1/records/%@/photos/%@", recordId, photo.photoType];
    }
    NSString *full = [NSString stringWithFormat:@"%@%@?token=%@&size=%ld",
                      self.baseURL, path, self.token, (long)size];
    return [NSURL URLWithString:full];
}

- (void)fetchPhotoData:(NSURL *)url completion:(APIDataCompletion)completion {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = 16 * 1024 * 1024;  // ~16 MB in-memory image cache
    });

    NSString *key = url.absoluteString;
    NSData *cached = [cache objectForKey:key];
    if (cached) { completion(cached, nil); return; }

    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                     timeoutInterval:30];
    [_TracqerHTTPConnection performRequest:req completion:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
        if (code != 200) { completion(nil, APIError(code, [NSString stringWithFormat:@"Photo HTTP %ld", (long)code])); return; }
        if (data) [cache setObject:data forKey:key cost:data.length];
        completion(data, nil);
    }];
}

@end
