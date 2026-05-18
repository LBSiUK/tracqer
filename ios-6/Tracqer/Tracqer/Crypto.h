@interface Crypto : NSObject

// Returns 32-byte AES-256 key derived via PBKDF2-SHA256, salt "vinyl-collection-salt", 100k iterations.
+ (NSData *)deriveKeyFromPassword:(NSString *)password;

// Token = lowercase hex of SHA-256(key).
+ (NSString *)tokenFromKey:(NSData *)key;

// Encrypt a JSON-serialisable object → @{@"iv": "<b64>", @"data": "<b64>"} dictionary.
+ (NSDictionary *)encryptObject:(id)object withKey:(NSData *)key error:(NSError **)error;

// Decrypt an envelope dictionary → JSON object.
+ (id)decryptEnvelope:(NSDictionary *)envelope withKey:(NSData *)key error:(NSError **)error;

// Base64 helpers (NSData's native base64 methods are iOS 7+; iOS 6 needs these).
+ (NSString *)base64StringFromData:(NSData *)data;
+ (NSData *)dataFromBase64String:(NSString *)s;

@end
