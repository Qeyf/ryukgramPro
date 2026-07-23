#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCIAudioCallConfirmBypassKey = &kSCIAudioCallConfirmBypassKey;
static const void *kSCIVideoCallConfirmBypassKey = &kSCIVideoCallConfirmBypassKey;

static BOOL sciConsumeCallConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayCallAction(id target, SEL selector, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static void sciReplayCallActionWithSender(id target, SEL selector, id sender, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, sender);
}

%hook IGDirectThreadCallButtonsCoordinator
// 426+ dropped the sender arg
- (void)_didTapAudioButton {
    if (sciConsumeCallConfirmBypass(self, kSCIAudioCallConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"voice_call_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayCallAction(weakSelf,
                            @selector(_didTapAudioButton),
                            kSCIAudioCallConfirmBypassKey);
    }];
}

- (void)_didTapVideoButton {
    if (sciConsumeCallConfirmBypass(self, kSCIVideoCallConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"video_call_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayCallAction(weakSelf,
                            @selector(_didTapVideoButton),
                            kSCIVideoCallConfirmBypassKey);
    }];
}

// Pre-426 signatures
- (void)_didTapAudioButton:(id)arg1 {
    if (sciConsumeCallConfirmBypass(self, kSCIAudioCallConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"voice_call_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedSender = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayCallActionWithSender(weakSelf,
                                      @selector(_didTapAudioButton:),
                                      capturedSender,
                                      kSCIAudioCallConfirmBypassKey);
    }];
}

- (void)_didTapVideoButton:(id)arg1 {
    if (sciConsumeCallConfirmBypass(self, kSCIVideoCallConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"video_call_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedSender = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayCallActionWithSender(weakSelf,
                                      @selector(_didTapVideoButton:),
                                      capturedSender,
                                      kSCIVideoCallConfirmBypassKey);
    }];
}
%end
