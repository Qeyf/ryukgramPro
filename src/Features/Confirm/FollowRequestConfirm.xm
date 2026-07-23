#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCIFollowRequestConfirmBypassKey = &kSCIFollowRequestConfirmBypassKey;

static BOOL sciConsumeFollowRequestConfirmBypass(id target) {
    if (![objc_getAssociatedObject(target, kSCIFollowRequestConfirmBypassKey) boolValue]) return NO;
    objc_setAssociatedObject(target,
                             kSCIFollowRequestConfirmBypassKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayFollowRequestAction(id target, SEL selector) {
    if (!target) return;
    objc_setAssociatedObject(target,
                             kSCIFollowRequestConfirmBypassKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

%hook IGPendingRequestView
- (void)_onApproveButtonTapped {
    if (sciConsumeFollowRequestConfirmBypass(self) ||
        ![SCIUtils getBoolPref:@"follow_request_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] Confirm follow request triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowRequestAction(weakSelf, @selector(_onApproveButtonTapped));
    }];
}

- (void)_onIgnoreButtonTapped {
    if (sciConsumeFollowRequestConfirmBypass(self) ||
        ![SCIUtils getBoolPref:@"follow_request_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] Confirm follow request triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowRequestAction(weakSelf, @selector(_onIgnoreButtonTapped));
    }];
}
%end
