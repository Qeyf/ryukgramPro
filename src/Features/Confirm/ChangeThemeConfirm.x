#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCIThemeNewPickerConfirmBypassKey = &kSCIThemeNewPickerConfirmBypassKey;
static const void *kSCIThemePickerConfirmBypassKey = &kSCIThemePickerConfirmBypassKey;
static const void *kSCIThemePreviewConfirmBypassKey = &kSCIThemePreviewConfirmBypassKey;

static BOOL sciConsumeThemeConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayThemeNewPickerSelection(id target, id controller, id theme, NSInteger index) {
    if (!target) return;
    objc_setAssociatedObject(target, kSCIThemeNewPickerConfirmBypassKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id, NSInteger))objc_msgSend)(
        target,
        @selector(themeNewPickerSectionController:didSelectTheme:atIndex:),
        controller,
        theme,
        index
    );
}

static void sciReplayThemePickerSelection(id target, id controller, id themeID) {
    if (!target) return;
    objc_setAssociatedObject(target, kSCIThemePickerConfirmBypassKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id))objc_msgSend)(
        target,
        @selector(themePickerSectionController:didSelectThemeId:),
        controller,
        themeID
    );
}

static void sciReplayThemePreviewSelection(id target) {
    if (!target) return;
    objc_setAssociatedObject(target, kSCIThemePreviewConfirmBypassKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, @selector(primaryButtonTapped));
}

%hook IGDirectThreadThemePickerViewController
- (void)themeNewPickerSectionController:(id)arg1 didSelectTheme:(id)arg2 atIndex:(NSInteger)arg3 {
    if (sciConsumeThemeConfirmBypass(self, kSCIThemeNewPickerConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        %orig(arg1, arg2, arg3);
        return;
    }

    NSLog(@"[SCInsta] Confirm change direct theme triggered");
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedTheme = arg2;
    NSInteger capturedIndex = arg3;
    [SCIUtils showConfirmation:^{
        sciReplayThemeNewPickerSelection(weakSelf,
                                         capturedController,
                                         capturedTheme,
                                         capturedIndex);
    }];
}

- (void)themePickerSectionController:(id)arg1 didSelectThemeId:(id)arg2 {
    if (sciConsumeThemeConfirmBypass(self, kSCIThemePickerConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        %orig(arg1, arg2);
        return;
    }

    NSLog(@"[SCInsta] Confirm change direct theme triggered");
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedThemeID = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayThemePickerSelection(weakSelf, capturedController, capturedThemeID);
    }];
}
%end

%hook IGDirectThreadThemeKitSwift.IGDirectThreadThemePreviewController
- (void)primaryButtonTapped {
    if (sciConsumeThemeConfirmBypass(self, kSCIThemePreviewConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"change_direct_theme_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] Confirm change direct theme triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayThemePreviewSelection(weakSelf);
    }];
}
%end
