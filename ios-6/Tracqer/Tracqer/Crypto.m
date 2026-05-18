#import "Crypto.h"
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

static const char kB64Alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString *Base64EncodeBytes(const uint8_t *bytes, NSUInteger len) {
    NSUInteger outLen = 4 * ((len + 2) / 3);
    char *out = malloc(outLen + 1);
    NSUInteger i, j;
    for (i = 0, j = 0; i < len; i += 3, j += 4) {
        uint32_t b0 = bytes[i];
        uint32_t b1 = (i + 1 < len) ? bytes[i + 1] : 0;
        uint32_t b2 = (i + 2 < len) ? bytes[i + 2] : 0;
        uint32_t v  = (b0 << 16) | (b1 << 8) | b2;
        out[j]     = kB64Alphabet[(v >> 18) & 0x3F];
        out[j + 1] = kB64Alphabet[(v >> 12) & 0x3F];
        out[j + 2] = (i + 1 < len) ? kB64Alphabet[(v >> 6)  & 0x3F] : '=';
        out[j + 3] = (i + 2 < len) ? kB64Alphabet[v         & 0x3F] : '=';
    }
    out[outLen] = '\0';
    NSString *s = [[NSString alloc] initWithBytesNoCopy:out length:outLen
                                               encoding:NSASCIIStringEncoding freeWhenDone:YES];
    return s;
}

static NSData *Base64DecodeString(NSString *s) {
    static int8_t table[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        memset(table, -1, sizeof(table));
        for (int i = 0; i < 64; i++) table[(uint8_t)kB64Alphabet[i]] = i;
        table[(uint8_t)'='] = 0;
    });

    NSData *raw = [s dataUsingEncoding:NSASCIIStringEncoding];
    if (!raw) return nil;
    const uint8_t *src = raw.bytes;
    NSUInteger srcLen = raw.length;

    while (srcLen > 0 && (src[srcLen - 1] == '\n' || src[srcLen - 1] == '\r' || src[srcLen - 1] == ' ')) srcLen--;
    if (srcLen % 4 != 0) return nil;

    NSUInteger padding = 0;
    if (srcLen >= 1 && src[srcLen - 1] == '=') padding++;
    if (srcLen >= 2 && src[srcLen - 2] == '=') padding++;

    NSUInteger outLen = (srcLen / 4) * 3 - padding;
    NSMutableData *out = [NSMutableData dataWithLength:outLen];
    uint8_t *dst = out.mutableBytes;

    NSUInteger di = 0;
    for (NSUInteger i = 0; i < srcLen; i += 4) {
        int8_t a = table[src[i]];
        int8_t b = table[src[i + 1]];
        int8_t c = table[src[i + 2]];
        int8_t d = table[src[i + 3]];
        if (a < 0 || b < 0 || c < 0 || d < 0) return nil;
        uint32_t v = ((uint32_t)a << 18) | ((uint32_t)b << 12) | ((uint32_t)c << 6) | (uint32_t)d;
        if (di < outLen) dst[di++] = (v >> 16) & 0xFF;
        if (di < outLen) dst[di++] = (v >> 8)  & 0xFF;
        if (di < outLen) dst[di++] =  v        & 0xFF;
    }
    return out;
}

static NSData *RandomIV16(void) {
    uint8_t buf[16];
    int rc = SecRandomCopyBytes(kSecRandomDefault, sizeof(buf), buf);
    if (rc != 0) return nil;
    return [NSData dataWithBytes:buf length:sizeof(buf)];
}

static NSError *CryptoError(NSInteger code, NSString *msg) {
    return [NSError errorWithDomain:@"TracqerCrypto"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

@implementation Crypto

+ (NSString *)base64StringFromData:(NSData *)data {
    if (!data) return nil;
    return Base64EncodeBytes(data.bytes, data.length);
}

+ (NSData *)dataFromBase64String:(NSString *)s {
    if (!s) return nil;
    return Base64DecodeString(s);
}

+ (NSData *)deriveKeyFromPassword:(NSString *)password {
    NSData *pwd  = [password dataUsingEncoding:NSUTF8StringEncoding];
    NSData *salt = [@"vinyl-collection-salt" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *out = [NSMutableData dataWithLength:32];

    int status = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      pwd.bytes,  pwd.length,
                                      salt.bytes, salt.length,
                                      kCCPRFHmacAlgSHA256,
                                      100000,
                                      out.mutableBytes, 32);
    if (status != kCCSuccess) return nil;
    return [out copy];
}

+ (NSString *)tokenFromKey:(NSData *)key {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(key.bytes, (CC_LONG)key.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [hex copy];
}

+ (NSDictionary *)encryptObject:(id)object withKey:(NSData *)key error:(NSError **)error {
    NSError *jsonErr = nil;
    NSData *plain = [NSJSONSerialization dataWithJSONObject:object options:0 error:&jsonErr];
    if (!plain) {
        if (error) *error = jsonErr ?: CryptoError(1, @"JSON serialization failed");
        return nil;
    }

    NSData *iv = RandomIV16();
    if (!iv) {
        if (error) *error = CryptoError(2, @"Failed to generate IV");
        return nil;
    }

    size_t outBufLen = plain.length + kCCBlockSizeAES128;
    NSMutableData *out = [NSMutableData dataWithLength:outBufLen];
    size_t nOut = 0;

    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes, kCCKeySizeAES256,
                                     iv.bytes,
                                     plain.bytes, plain.length,
                                     out.mutableBytes, outBufLen,
                                     &nOut);
    if (status != kCCSuccess) {
        if (error) *error = CryptoError(status, @"AES encryption failed");
        return nil;
    }
    out.length = nOut;

    return @{ @"iv":   Base64EncodeBytes(iv.bytes,  iv.length),
              @"data": Base64EncodeBytes(out.bytes, out.length) };
}

+ (id)decryptEnvelope:(NSDictionary *)envelope withKey:(NSData *)key error:(NSError **)error {
    NSString *ivB64  = envelope[@"iv"];
    NSString *datB64 = envelope[@"data"];
    if (![ivB64 isKindOfClass:[NSString class]] || ![datB64 isKindOfClass:[NSString class]]) {
        if (error) *error = CryptoError(3, @"Invalid envelope shape");
        return nil;
    }

    NSData *iv     = Base64DecodeString(ivB64);
    NSData *cipher = Base64DecodeString(datB64);
    if (!iv || !cipher) {
        if (error) *error = CryptoError(4, @"Envelope base64 decode failed");
        return nil;
    }

    size_t outBufLen = cipher.length + kCCBlockSizeAES128;
    NSMutableData *out = [NSMutableData dataWithLength:outBufLen];
    size_t nOut = 0;

    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes, kCCKeySizeAES256,
                                     iv.bytes,
                                     cipher.bytes, cipher.length,
                                     out.mutableBytes, outBufLen,
                                     &nOut);
    if (status != kCCSuccess) {
        if (error) *error = CryptoError(status, @"AES decryption failed (wrong password?)");
        return nil;
    }
    out.length = nOut;

    NSError *jsonErr = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:out options:0 error:&jsonErr];
    if (!obj) {
        if (error) *error = jsonErr ?: CryptoError(5, @"Decrypted payload is not JSON");
        return nil;
    }
    return obj;
}

@end
