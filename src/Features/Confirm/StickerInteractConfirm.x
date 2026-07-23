#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Split by _analyticsModule: "highlight" substring → highlights toggle, else stories toggle.

static const void *kSCIStickerInteractConfirmBypassKey = &kSCIStickerInteractConfirmBypassKey;

static BOOL sciTapIsHighlight(id target) {
    Ivar iv = class_getInstanceVariable(object_getClass(target), "_analyticsModule");
    if (!iv) return NO;
    id value = nil;
    @try { value = object_getIvar(target, iv); }
    @catch (__unused NSException *exception) { return NO; }
    if (![value isKindOfClass:[NSString class]]) return NO;
    return [((NSString *)value).lowercaseString containsString:@"highlight"];
}

static BOOL sciConsumeStickerInteractConfirmBypass(id target) {
    if (![objc_getAssociatedObject(target, kSCIStickerInteractConfirmBypassKey) boolValue]) return NO;
    objc_setAssociatedObject(target,
                             kSCIStickerInteractConfirmBypassKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayStickerInteraction(id target, id tap, id event) {
    if (!target) return;
    objc_setAssociatedObject(target,
                             kSCIStickerInteractConfirmBypassKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id))objc_msgSend)(target,
                                              @selector(_didTap:forEvent:),
                                              tap,
                                              event);
}

%hook IGStoryViewerTapTarget
- (void)_didTap:(id)arg1 forEvent:(id)arg2 {
    NSString *key = sciTapIsHighlight(self)
        ? @"sticker_interact_confirm_highlights"
        : @"sticker_interact_confirm";

    if (sciConsumeStickerInteractConfirmBypass(self) ||
        ![SCIUtils getBoolPref:key]) {
        %orig(arg1, arg2);
        return;
    }

    __weak id weakSelf = self;
    id capturedTap = arg1;
    id capturedEvent = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayStickerInteraction(weakSelf, capturedTap, capturedEvent);
    }];
}
%end
