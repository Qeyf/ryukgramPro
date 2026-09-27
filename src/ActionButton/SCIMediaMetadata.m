#import "SCIMediaMetadata.h"
#import <objc/runtime.h>

NSDictionary *SCIFieldCacheForObject(id object) {
    if ([object isKindOfClass:[NSDictionary class]]) return object;
    if (!object) return nil;

    Ivar ivar = NULL;
    for (Class cls = object_getClass(object); cls && !ivar; cls = class_getSuperclass(cls)) {
        ivar = class_getInstanceVariable(cls, "_fieldCache");
    }
    if (!ivar) return nil;

    id cache = object_getIvar(object, ivar);
    return [cache isKindOfClass:[NSDictionary class]] ? cache : nil;
}

id SCIFieldCacheValue(id object, NSString *key) {
    if (!key.length) return nil;
    id value = SCIFieldCacheForObject(object)[key];
    return [value isKindOfClass:[NSNull class]] ? nil : value;
}

NSString *SCICaptionWithSource(NSString *caption, NSString *username) {
    if (!caption.length || !username.length) return caption;

    NSUInteger length = caption.length;
    while (length > 0) {
        unichar tail = [caption characterAtIndex:length - 1];
        if (tail != '\r' && tail != '\n') break;
        length--;
    }
    NSString *body = length == caption.length ? caption : [caption substringToIndex:length];
    NSString *credit = [username hasPrefix:@"@"] ? username : [@"@" stringByAppendingString:username];
    return [NSString stringWithFormat:@"%@\n\nkaynak: %@", body, credit];
}
