#ifndef Tracqer_Constants_h
#define Tracqer_Constants_h

extern NSString * const kTracqerDefaultsKeyServerURL;
extern NSString * const kTracqerDefaultsKeyAESKey;
extern NSString * const kTracqerDefaultsKeyAuthToken;

extern NSString * const kTracqerOwnerMe;
extern NSString * const kTracqerOwnerDad;
extern NSString * const kTracqerOwnerShared;

extern NSString * const kTracqerFormat12LP;
extern NSString * const kTracqerFormat10LP;
extern NSString * const kTracqerFormat12Single;
extern NSString * const kTracqerFormat7Single;
extern NSString * const kTracqerFormatOther;

extern NSString * const kTracqerSpeed33;
extern NSString * const kTracqerSpeed45;
extern NSString * const kTracqerSpeed78;

NSArray *TracqerAllOwners(void);
NSArray *TracqerAllFormats(void);
NSArray *TracqerAllSpeeds(void);
NSArray *TracqerAllGrades(void);

#endif
