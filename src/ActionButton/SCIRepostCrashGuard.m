#import "SCIMediaActions.h"
#import "SCIRepostSheet.h"
#import "SCIActionMenu.h"
#import "../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Instagram 434 no longer guarantees that every object exposing media-like
// selectors inherits the historical IGAPIStorableObject layout. Reusing an
// Ivar captured from that base class with object_getIvar() on another class is
// a process-fatal runtime error (it is not catchable as an Objective-C
// exception). Resolve the ivar from the concrete object's hierarchy instead.
static id sciCrashSafeObjectIvar(id object, const char *name) {
    if (!object || !name) return nil;
    Class concreteClass = object_getClass(object);
    if (!concreteClass) return nil;

    Ivar ivar = class_getInstanceVariable(concreteClass, name);
    if (!ivar) return nil;

    const char *type = ivar_getTypeEncoding(ivar);
    if (!type || type[0] != '@') return nil;

    return object_getIvar(object, ivar);
}

static id sciCrashSafeFieldCacheValue(id object, NSString *key) {
    if (!object || !key.length) return nil;
    id cache = sciCrashSafeObjectIvar(object, "_fieldCache");
    if (![cache isKindOfClass:[NSDictionary class]]) return nil;

    id value = ((NSDictionary *)cache)[key];
    return (!value || [value isKindOfClass:[NSNull class]]) ? nil : value;
}

static NSString *sciCrashSafeStringFromCaptionObject(id object) {
    if (!object || [object isKindOfClass:[NSNull class]]) return nil;
    if ([object isKindOfClass:[NSString class]]) {
        return [(NSString *)object length] ? object : nil;
    }
    if ([object isKindOfClass:[NSAttributedString class]]) {
        NSString *string = [(NSAttributedString *)object string];
        return string.length ? string : nil;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in @[@"text", @"caption", @"string", @"raw_text", @"rawText"]) {
            NSString *string = sciCrashSafeStringFromCaptionObject(((NSDictionary *)object)[key]);
            if (string.length) return string;
        }
    }

    for (NSString *selectorName in @[@"text", @"string", @"commentText", @"rawText", @"attributedString"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![object respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
        NSString *string = sciCrashSafeStringFromCaptionObject(value);
        if (string.length) return string;
    }

    id cachedText = sciCrashSafeFieldCacheValue(object, @"text");
    return sciCrashSafeStringFromCaptionObject(cachedText);
}

static NSString *sciCrashSafeCaptionForMedia(id self, SEL _cmd, id media) {
    (void)self;
    (void)_cmd;
    if (!media) return nil;

    for (NSString *selectorName in @[@"fullCaptionString", @"captionString", @"caption", @"captionText", @"text"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![media respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(media, selector);
        NSString *string = sciCrashSafeStringFromCaptionObject(value);
        if (string.length) return string;
    }

    NSString *cachedCaption = sciCrashSafeStringFromCaptionObject(
        sciCrashSafeFieldCacheValue(media, @"caption")
    );
    if (cachedCaption.length) return cachedCaption;

    // Last-resort concrete-class ivar scan. Every Ivar comes from the same
    // class object passed to object_getIvar(), so it remains runtime-safe.
    for (Class cls = object_getClass(media); cls; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index++) {
            const char *name = ivar_getName(ivars[index]);
            const char *type = ivar_getTypeEncoding(ivars[index]);
            if (!name || !type || type[0] != '@') continue;

            NSString *ivarName = [[NSString stringWithUTF8String:name] lowercaseString];
            if (![ivarName containsString:@"caption"]) continue;

            NSString *string = sciCrashSafeStringFromCaptionObject(object_getIvar(media, ivars[index]));
            if (string.length) {
                free(ivars);
                return string;
            }
        }
        if (ivars) free(ivars);
    }

    return nil;
}

static NSArray *sciCrashSafeCarouselChildren(id self, SEL _cmd, id media) {
    (void)self;
    (void)_cmd;
    if (!media) return @[];

    for (NSString *selectorName in @[@"carouselMedia", @"carouselChildren", @"children"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![media respondsToSelector:selector]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(media, selector);
        if ([value isKindOfClass:[NSArray class]] && [(NSArray *)value count]) return value;
    }

    for (NSString *ivarName in @[@"_carouselMedia", @"_carouselChildren"]) {
        id value = sciCrashSafeObjectIvar(media, ivarName.UTF8String);
        if ([value isKindOfClass:[NSArray class]] && [(NSArray *)value count]) return value;
    }

    id cachedChildren = sciCrashSafeFieldCacheValue(media, @"carousel_media");
    return [cachedChildren isKindOfClass:[NSArray class]] ? cachedChildren : @[];
}

static BOOL sciCrashSafeIsCarousel(id self, SEL _cmd, id media) {
    (void)_cmd;
    if (!media) return NO;

    SEL isCarouselSelector = NSSelectorFromString(@"isCarousel");
    if ([media respondsToSelector:isCarouselSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(media, isCarouselSelector)) {
        return YES;
    }

    SEL mediaTypeSelector = NSSelectorFromString(@"mediaType");
    if ([media respondsToSelector:mediaTypeSelector]) {
        NSInteger mediaType = ((NSInteger (*)(id, SEL))objc_msgSend)(media, mediaTypeSelector);
        if (mediaType == 8) return YES;
    }

    return sciCrashSafeCarouselChildren(self,
                                        @selector(carouselChildrenForMedia:),
                                        media).count > 0;
}

static NSArray<SCIAction *> *(*sciOriginalActionsForContext)(id, SEL, SCIActionContext, id, UIView *) = NULL;

static NSArray<SCIAction *> *sciCrashSafeActionsForContext(id self,
                                                           SEL _cmd,
                                                           SCIActionContext context,
                                                           id media,
                                                           UIView *sourceView) {
    NSArray<SCIAction *> *original = sciOriginalActionsForContext
        ? sciOriginalActionsForContext(self, _cmd, context, media, sourceView)
        : @[];
    if (!original.count) return original;

    NSString *localizedRepost = [SCILocalized(@"Repost") lowercaseString];
    NSMutableArray<SCIAction *> *result = [NSMutableArray arrayWithCapacity:original.count];
    __weak UIView *weakSourceView = sourceView;
    id capturedMedia = media;

    for (SCIAction *action in original) {
        NSString *title = [action.title lowercaseString];
        BOOL isRepostAction = !action.isSeparator &&
            ([title isEqualToString:localizedRepost] ||
             [title containsString:@"repost"] ||
             [title containsString:@"yeniden paylaş"] ||
             [title containsString:@"yeniden paylas"]);

        if (!isRepostAction) {
            [result addObject:action];
            continue;
        }

        SCIAction *safeAction = [SCIAction actionWithTitle:action.title
                                                  subtitle:action.subtitle
                                                      icon:action.systemIconName
                                               destructive:action.destructive
                                                   handler:^{
            [SCIRepostSheet presentForMedia:capturedMedia fromView:weakSourceView];
        }];
        [result addObject:safeAction];
    }

    return result;
}

// Any legacy URL-only caller must also avoid the old visible-view-tree media
// resolver. It can still open the destination picker, but without attempting to
// reinterpret arbitrary UIView instances as IGMedia objects.
static void sciCrashSafeLegacyURLRepost(id self,
                                        SEL _cmd,
                                        NSURL *videoURL,
                                        NSURL *photoURL) {
    (void)_cmd;
    SEL pickerSelector = NSSelectorFromString(
        @"presentDestinationPickerForMedia:videoURL:photoURL:sourceView:"
    );
    if (![self respondsToSelector:pickerSelector]) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Unable to open creator")];
        return;
    }

    UIViewController *controller = topMostController();
    ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(self,
                                                       pickerSelector,
                                                       nil,
                                                       videoURL,
                                                       photoURL,
                                                       controller.view);
}

@implementation SCIMediaActions (SCIRepostCrashGuard)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method captionMethod = class_getClassMethod(self, @selector(captionForMedia:));
        Method childrenMethod = class_getClassMethod(self, @selector(carouselChildrenForMedia:));
        Method carouselMethod = class_getClassMethod(self, @selector(isCarouselMedia:));
        Method actionsMethod = class_getClassMethod(self, @selector(actionsForContext:media:fromView:));

        if (captionMethod) method_setImplementation(captionMethod, (IMP)sciCrashSafeCaptionForMedia);
        if (childrenMethod) method_setImplementation(childrenMethod, (IMP)sciCrashSafeCarouselChildren);
        if (carouselMethod) method_setImplementation(carouselMethod, (IMP)sciCrashSafeIsCarousel);
        if (actionsMethod) {
            sciOriginalActionsForContext = (void *)method_getImplementation(actionsMethod);
            method_setImplementation(actionsMethod, (IMP)sciCrashSafeActionsForContext);
        }

        Class repostClass = NSClassFromString(@"SCIRepostSheet");
        Method legacyMethod = class_getClassMethod(repostClass,
                                                   @selector(repostWithVideoURL:photoURL:));
        if (legacyMethod) method_setImplementation(legacyMethod, (IMP)sciCrashSafeLegacyURLRepost);

        NSLog(@"[RyukGram][Repost] Installed Instagram 434 field-cache crash guard");
    });
}

@end
