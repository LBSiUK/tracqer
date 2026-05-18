#import "Constants.h"

NSString * const kTracqerDefaultsKeyServerURL  = @"TracqerServerURL";
NSString * const kTracqerDefaultsKeyAESKey     = @"TracqerAESKey";
NSString * const kTracqerDefaultsKeyAuthToken  = @"TracqerAuthToken";

NSString * const kTracqerOwnerMe     = @"me";
NSString * const kTracqerOwnerDad    = @"dad";
NSString * const kTracqerOwnerShared = @"shared";

NSString * const kTracqerFormat12LP     = @"12\" LP";
NSString * const kTracqerFormat10LP     = @"10\" LP";
NSString * const kTracqerFormat12Single = @"12\" single";
NSString * const kTracqerFormat7Single  = @"7\" single";
NSString * const kTracqerFormatOther    = @"Other";

NSString * const kTracqerSpeed33 = @"33";
NSString * const kTracqerSpeed45 = @"45";
NSString * const kTracqerSpeed78 = @"78";

NSArray *TracqerAllOwners(void) {
    return @[kTracqerOwnerMe, kTracqerOwnerDad, kTracqerOwnerShared];
}

NSArray *TracqerAllFormats(void) {
    return @[kTracqerFormat12LP, kTracqerFormat10LP, kTracqerFormat12Single, kTracqerFormat7Single, kTracqerFormatOther];
}

NSArray *TracqerAllSpeeds(void) {
    return @[kTracqerSpeed33, kTracqerSpeed45, kTracqerSpeed78];
}

NSArray *TracqerAllGrades(void) {
    return @[@"M", @"NM", @"VG+", @"VG", @"G+", @"G", @"F", @"P"];
}
