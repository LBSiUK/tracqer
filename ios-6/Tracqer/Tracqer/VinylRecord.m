#import "VinylRecord.h"
#import "Constants.h"

static id NullToNil(id v) {
    return (v == nil || v == [NSNull null]) ? nil : v;
}

@implementation Photo

+ (instancetype)photoFromDictionary:(NSDictionary *)dict {
    Photo *p      = [[Photo alloc] init];
    p.photoId     = NullToNil(dict[@"id"]);
    p.photoType   = NullToNil(dict[@"photo_type"]);
    p.discNumber  = NullToNil(dict[@"disc_number"]);
    p.mimeType    = NullToNil(dict[@"mime_type"]);
    p.fileSize    = [NullToNil(dict[@"file_size"]) integerValue];
    p.createdAt   = NullToNil(dict[@"created_at"]);
    return p;
}

- (BOOL)isDiscPhoto {
    return [self.photoType isEqualToString:@"disc_front"] || [self.photoType isEqualToString:@"disc_back"];
}

- (NSString *)displayLabel {
    NSDictionary *map = @{
        @"sleeve_front":       @"Front",
        @"sleeve_back":        @"Back",
        @"sleeve_inner":       @"Gatefold",
        @"inner_sleeve_front": @"Inner (Front)",
        @"inner_sleeve_back":  @"Inner (Back)",
        @"disc_front":         @"Disc Front",
        @"disc_back":          @"Disc Back",
    };
    NSString *base = map[self.photoType] ?: self.photoType;
    if ([self isDiscPhoto] && self.discNumber) {
        return [NSString stringWithFormat:@"%@ %@", base, self.discNumber];
    }
    return base;
}

@end

#pragma mark -

@implementation VinylRecord

+ (instancetype)recordFromDictionary:(NSDictionary *)dict {
    VinylRecord *r       = [[VinylRecord alloc] init];
    r.recordId           = NullToNil(dict[@"id"]);
    r.title              = NullToNil(dict[@"title"]);
    r.artist             = NullToNil(dict[@"artist"]);
    r.year               = NullToNil(dict[@"year"]);
    r.duration           = NullToNil(dict[@"duration"]);
    r.label              = NullToNil(dict[@"label"]);
    r.format             = NullToNil(dict[@"format"]);
    r.speed              = NullToNil(dict[@"speed"]);
    r.genre              = NullToNil(dict[@"genre"]);
    r.notes              = NullToNil(dict[@"notes"]);
    r.owner              = NullToNil(dict[@"owner"]) ?: @"me";
    r.discCount          = [NullToNil(dict[@"disc_count"]) integerValue] ?: 1;
    r.outerSleeveOnly    = [NullToNil(dict[@"outer_sleeve_only"]) boolValue];
    r.discCondition      = NullToNil(dict[@"disc_condition"]);
    r.sleeveCondition    = NullToNil(dict[@"sleeve_condition"]);
    r.createdAt          = NullToNil(dict[@"created_at"]);
    r.updatedAt          = NullToNil(dict[@"updated_at"]);

    NSArray *rawPhotos = NullToNil(dict[@"photos"]);
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:rawPhotos.count];
    for (NSDictionary *d in rawPhotos) {
        if ([d isKindOfClass:[NSDictionary class]]) [photos addObject:[Photo photoFromDictionary:d]];
    }
    r.photos = photos;
    return r;
}

- (NSDictionary *)toDictionaryForInput {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"title"]              = self.title ?: @"";
    d[@"artist"]             = self.artist ?: @"";
    d[@"owner"]              = self.owner ?: kTracqerOwnerMe;
    d[@"disc_count"]         = @(self.discCount ?: 1);
    d[@"outer_sleeve_only"]  = @(self.outerSleeveOnly);
    if (self.year)             d[@"year"]              = self.year;
    if (self.duration)         d[@"duration"]          = self.duration;
    if (self.label)            d[@"label"]             = self.label;
    if (self.format)           d[@"format"]            = self.format;
    if (self.speed)            d[@"speed"]             = self.speed;
    if (self.genre)            d[@"genre"]             = self.genre;
    if (self.notes)            d[@"notes"]             = self.notes;
    if (self.discCondition)    d[@"disc_condition"]    = self.discCondition;
    if (self.sleeveCondition)  d[@"sleeve_condition"]  = self.sleeveCondition;
    return d;
}

@end
