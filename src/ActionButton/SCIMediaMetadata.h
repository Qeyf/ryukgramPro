#import <Foundation/Foundation.h>

// v1.4.0 recovery: Objective-C methods at 0x38da24, 0x38dcb0 and the
// caption formatter at 0x4a4100 in the supplied arm64 image.
FOUNDATION_EXPORT NSDictionary * _Nullable SCIFieldCacheForObject(id _Nullable object);
FOUNDATION_EXPORT id _Nullable SCIFieldCacheValue(id _Nullable object, NSString * _Nullable key);
FOUNDATION_EXPORT NSString * _Nullable SCICaptionWithSource(NSString * _Nullable caption,
                                                           NSString * _Nullable username);
