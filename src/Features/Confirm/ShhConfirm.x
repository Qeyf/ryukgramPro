#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCIDisappearingSwipeConfirmBypassKey = &kSCIDisappearingSwipeConfirmBypassKey;
static const void *kSCIShhToggleConfirmBypassKey = &kSCIShhToggleConfirmBypassKey;
static const void *kSCIShhReplayConfirmBypassKey = &kSCIShhReplayConfirmBypassKey;

static BOOL sciConsumeShhConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayShhAction(id target, SEL selector, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static void sciReplayShhActionWithArgument(id target, SEL selector, id argument, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
}

%hook IGDirectDisappearingModeSwipeHandler
- (void)handleBottomSwipeableScrollUpdate {
    if ([SCIUtils getBoolPref:@"disable_disappearing_mode_swipe"]) return;

    if (sciConsumeShhConfirmBypass(self, kSCIDisappearingSwipeConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayShhAction(weakSelf,
                           @selector(handleBottomSwipeableScrollUpdate),
                           kSCIDisappearingSwipeConfirmBypassKey);
    }];
}

- (id)getSwipeableScrollHintTextInfo {
    if ([SCIUtils getBoolPref:@"disable_disappearing_mode_swipe"]) return nil;
    return %orig;
}
%end

%hook IGDirectThreadViewController
- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if (sciConsumeShhConfirmBypass(self, kSCIShhToggleConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayShhActionWithArgument(weakSelf,
                                       @selector(messageListViewControllerDidToggleShhMode:),
                                       capturedArgument,
                                       kSCIShhToggleConfirmBypassKey);
    }];
}

- (void)messageListViewControllerDidReplayInShhMode:(id)arg1 {
    if (sciConsumeShhConfirmBypass(self, kSCIShhReplayConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayShhActionWithArgument(weakSelf,
                                       @selector(messageListViewControllerDidReplayInShhMode:),
                                       capturedArgument,
                                       kSCIShhReplayConfirmBypassKey);
    }];
}
%end
