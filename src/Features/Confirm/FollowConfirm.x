#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

static const void *kSCIFollowConfirmBypassKey = &kSCIFollowConfirmBypassKey;
static const void *kSCIUnfollowConfirmBypassKey = &kSCIUnfollowConfirmBypassKey;

static BOOL sciConsumeFollowConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayFollowAction(id target, SEL selector, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static void sciReplayFollowActionWithArgument(id target,
                                               SEL selector,
                                               id argument,
                                               const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, argument);
}

static void sciReplayFollowActionWithArguments(id target,
                                                SEL selector,
                                                id firstArgument,
                                                id secondArgument,
                                                const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id))objc_msgSend)(target,
                                              selector,
                                              firstArgument,
                                              secondArgument);
}

// Follow button on profile page and unfollow from profile action sheet.
%hook IGFollowController
- (void)_didPressFollowButton {
    NSInteger status = self.user.followStatus;
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        status != 2 ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] Confirm follow triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowAction(weakSelf,
                              @selector(_didPressFollowButton),
                              kSCIFollowConfirmBypassKey);
    }];
}

- (void)_performUnfollow {
    if (sciConsumeFollowConfirmBypass(self, kSCIUnfollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"unfollow_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowAction(weakSelf,
                              @selector(_performUnfollow),
                              kSCIUnfollowConfirmBypassKey);
    } title:SCILocalized(@"Unfollow?")];
}
%end

// Follow button on discover people page.
%hook IGDiscoverPeopleButtonGroupView
- (void)_onFollowButtonTapped:(id)arg1 {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayFollowActionWithArgument(weakSelf,
                                          @selector(_onFollowButtonTapped:),
                                          capturedArgument,
                                          kSCIFollowConfirmBypassKey);
    }];
}

- (void)_onFollowingButtonTapped:(id)arg1 {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayFollowActionWithArgument(weakSelf,
                                          @selector(_onFollowingButtonTapped:),
                                          capturedArgument,
                                          kSCIFollowConfirmBypassKey);
    }];
}
%end

// Suggested for you follow button.
%hook IGHScrollAYMFCell
- (void)_didTapAYMFActionButton {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowAction(weakSelf,
                              @selector(_didTapAYMFActionButton),
                              kSCIFollowConfirmBypassKey);
    }];
}
%end

%hook IGHScrollAYMFActionButton
- (void)_didTapTextActionButton {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig;
        return;
    }

    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayFollowAction(weakSelf,
                              @selector(_didTapTextActionButton),
                              kSCIFollowConfirmBypassKey);
    }];
}
%end

// Follow button on reels.
%hook IGUnifiedVideoFollowButton
- (void)_hackilyHandleOurOwnButtonTaps:(id)arg1 event:(id)arg2 {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig(arg1, arg2);
        return;
    }

    __weak id weakSelf = self;
    id capturedButton = arg1;
    id capturedEvent = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayFollowActionWithArguments(weakSelf,
                                           @selector(_hackilyHandleOurOwnButtonTaps:event:),
                                           capturedButton,
                                           capturedEvent,
                                           kSCIFollowConfirmBypassKey);
    }];
}
%end

// Follow text on profile when collapsed into the top bar.
%hook IGProfileViewController
- (void)navigationItemsControllerDidTapHeaderFollowButton:(id)arg1 {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig(arg1);
        return;
    }

    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayFollowActionWithArgument(weakSelf,
                                          @selector(navigationItemsControllerDidTapHeaderFollowButton:),
                                          capturedArgument,
                                          kSCIFollowConfirmBypassKey);
    }];
}
%end

// Follow button on suggested friends in the story section.
%hook IGStorySectionController
- (void)followButtonTapped:(id)arg1 cell:(id)arg2 {
    if (sciConsumeFollowConfirmBypass(self, kSCIFollowConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"follow_confirm"]) {
        %orig(arg1, arg2);
        return;
    }

    __weak id weakSelf = self;
    id capturedButton = arg1;
    id capturedCell = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayFollowActionWithArguments(weakSelf,
                                           @selector(followButtonTapped:cell:),
                                           capturedButton,
                                           capturedCell,
                                           kSCIFollowConfirmBypassKey);
    }];
}
%end

// Follow-all button in group-chat people view.
static void (*orig_listSectionController)(id, SEL, id, id);

static void hooked_listSectionController(id self, SEL _cmd, id arg1, id arg2) {
    if ([SCIUtils getBoolPref:@"follow_confirm"]) {
        [SCIUtils showConfirmation:^{
            orig_listSectionController(self, _cmd, arg1, arg2);
        }];
        return;
    }

    orig_listSectionController(self, _cmd, arg1, arg2);
}

%ctor {
    Class cls = objc_getClass("IGDirectDetailMembersKit.IGDirectThreadDetailsMembersListViewController");
    if (!cls) return;

    MSHookMessageEx(
        cls,
        @selector(listSectionController:didTapHeaderButtonWithViewModel:),
        (IMP)hooked_listSectionController,
        (IMP *)&orig_listSectionController
    );
}
