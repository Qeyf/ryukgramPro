#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// Reels like tap goes through a Swift class method on
// IGSundialViewerLikeButtonActionHandler since IG 426.
typedef void (*SciHandleTapFn)(Class, SEL, id, id, BOOL);
typedef void (*SciHandleTapCompFn)(Class, SEL, id, id, BOOL, id);
static SciHandleTapFn orig_sciHandleTap = NULL;
static SciHandleTapCompFn orig_sciHandleTapComp = NULL;

static void new_sciHandleTap(Class cls, SEL _cmd, id ctx, id btn, BOOL anim) {
    if (![SCIUtils getBoolPref:@"like_confirm_reels"]) {
        orig_sciHandleTap(cls, _cmd, ctx, btn, anim);
        return;
    }
    __strong id strongContext = ctx;
    __strong id strongButton = btn;
    [SCIUtils showConfirmation:^{
        @try { orig_sciHandleTap(cls, _cmd, strongContext, strongButton, anim); }
        @catch (__unused NSException *exception) {}
    }];
}

// Copy the completion block because a stack block cannot outlive the alert call.
static void new_sciHandleTapComp(Class cls, SEL _cmd, id ctx, id btn, BOOL anim, id comp) {
    if (![SCIUtils getBoolPref:@"like_confirm_reels"]) {
        orig_sciHandleTapComp(cls, _cmd, ctx, btn, anim, comp);
        return;
    }
    __strong id strongContext = ctx;
    __strong id strongButton = btn;
    id strongCompletion = comp ? [comp copy] : nil;
    [SCIUtils showConfirmation:^{
        @try {
            orig_sciHandleTapComp(cls,
                                  _cmd,
                                  strongContext,
                                  strongButton,
                                  anim,
                                  strongCompletion);
        } @catch (__unused NSException *exception) {}
    }];
}

__attribute__((constructor)) static void _sciHookReelsLikeHandler(void) {
    Class targetClass = NSClassFromString(
        @"_TtC30IGSundialOverlayActionHandlers38IGSundialViewerLikeButtonActionHandler"
    );
    if (!targetClass) return;
    Class metaClass = object_getClass(targetClass);
    SEL tapSelector = NSSelectorFromString(
        @"handleTapWithActionContext:likeButton:willPlayRingsCustomLikeAnimation:"
    );
    SEL completionSelector = NSSelectorFromString(
        @"handleTapWithActionContext:likeButton:willPlayRingsCustomLikeAnimation:completion:"
    );
    if (class_getClassMethod(targetClass, tapSelector)) {
        MSHookMessageEx(metaClass,
                        tapSelector,
                        (IMP)new_sciHandleTap,
                        (IMP *)&orig_sciHandleTap);
    }
    if (class_getClassMethod(targetClass, completionSelector)) {
        MSHookMessageEx(metaClass,
                        completionSelector,
                        (IMP)new_sciHandleTapComp,
                        (IMP *)&orig_sciHandleTapComp);
    }
}

static const void *kSCIPostLikeConfirmBypassKey = &kSCIPostLikeConfirmBypassKey;
static const void *kSCIReelsLikeConfirmBypassKey = &kSCIReelsLikeConfirmBypassKey;

static BOOL sciConsumeLikeConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static BOOL sciShouldConfirmLike(id target, const void *key, NSString *preferenceKey) {
    return !sciConsumeLikeConfirmBypass(target, key) &&
           [SCIUtils getBoolPref:preferenceKey];
}

static void sciReplayLikeAction(id target, SEL selector, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

static void sciReplayLikeAction1(id target, SEL selector, id arg1, const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, arg1);
}

static void sciReplayLikeAction2(id target,
                                 SEL selector,
                                 id arg1,
                                 id arg2,
                                 const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id))objc_msgSend)(target, selector, arg1, arg2);
}

static void sciReplayLikeAction3(id target,
                                 SEL selector,
                                 id arg1,
                                 id arg2,
                                 id arg3,
                                 const void *key) {
    if (!target) return;
    objc_setAssociatedObject(target, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id, id))objc_msgSend)(target,
                                                  selector,
                                                  arg1,
                                                  arg2,
                                                  arg3);
}

// MARK: - Post likes

%hook IGUFIButtonBarView
- (void)_onLikeButtonPressed:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(_onLikeButtonPressed:),
                             capturedArgument,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)_onLikeButtonPressed {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig;
        return;
    }
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction(weakSelf,
                            @selector(_onLikeButtonPressed),
                            kSCIPostLikeConfirmBypassKey);
    }];
}
%end

%hook IGFeedPhotoView
- (void)_onDoubleTap:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(_onDoubleTap:),
                             capturedArgument,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)_onDoubleTap {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig;
        return;
    }
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction(weakSelf,
                            @selector(_onDoubleTap),
                            kSCIPostLikeConfirmBypassKey);
    }];
}
%end

%hook IGVideoPlayerOverlayContainerView
- (void)_handleDoubleTapGesture:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedGesture = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(_handleDoubleTapGesture:),
                             capturedGesture,
                             kSCIPostLikeConfirmBypassKey);
    }];
}
%end

// MARK: - Reels likes

%hook IGSundialViewerVideoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(controlsOverlayControllerDidTapLikeButton:),
                             capturedArgument,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}

- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1, arg2);
        return;
    }
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedTap = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction2(weakSelf,
                             @selector(gestureController:didObserveDoubleTap:),
                             capturedController,
                             capturedTap,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}
%end

%hook IGSundialViewerPhotoCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(controlsOverlayControllerDidTapLikeButton:),
                             capturedArgument,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}

- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1, arg2);
        return;
    }
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedTap = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction2(weakSelf,
                             @selector(gestureController:didObserveDoubleTap:),
                             capturedController,
                             capturedTap,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}

- (void)swift_photoCell:(id)arg1
    didObserveDoubleTapWithLocationInfo:(id)arg2
                     gestureRecognizer:(id)arg3 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1, arg2, arg3);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    id capturedLocation = arg2;
    id capturedGesture = arg3;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction3(weakSelf,
                             @selector(swift_photoCell:didObserveDoubleTapWithLocationInfo:gestureRecognizer:),
                             capturedCell,
                             capturedLocation,
                             capturedGesture,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}
%end

%hook IGSundialViewerCarouselCell
- (void)controlsOverlayControllerDidTapLikeButton:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedArgument = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(controlsOverlayControllerDidTapLikeButton:),
                             capturedArgument,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}

- (void)gestureController:(id)arg1 didObserveDoubleTap:(id)arg2 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1, arg2);
        return;
    }
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedTap = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction2(weakSelf,
                             @selector(gestureController:didObserveDoubleTap:),
                             capturedController,
                             capturedTap,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}

- (void)carouselCell:(id)arg1
    didObserveDoubleTapWithLocationInfo:(id)arg2
                     gestureRecognizer:(id)arg3 {
    if (!sciShouldConfirmLike(self, kSCIReelsLikeConfirmBypassKey, @"like_confirm_reels")) {
        %orig(arg1, arg2, arg3);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    id capturedLocation = arg2;
    id capturedGesture = arg3;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction3(weakSelf,
                             @selector(carouselCell:didObserveDoubleTapWithLocationInfo:gestureRecognizer:),
                             capturedCell,
                             capturedLocation,
                             capturedGesture,
                             kSCIReelsLikeConfirmBypassKey);
    }];
}
%end

// MARK: - Comment likes

%hook IGCommentCellController
- (void)commentCell:(id)arg1 didTapLikeButton:(id)arg2 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1, arg2);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    id capturedButton = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction2(weakSelf,
                             @selector(commentCell:didTapLikeButton:),
                             capturedCell,
                             capturedButton,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)commentCell:(id)arg1 didTapLikedByButtonForUser:(id)arg2 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1, arg2);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    id capturedUser = arg2;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction2(weakSelf,
                             @selector(commentCell:didTapLikedByButtonForUser:),
                             capturedCell,
                             capturedUser,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)commentCellDidLongPressOnLikeButton:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(commentCellDidLongPressOnLikeButton:),
                             capturedCell,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)commentCellDidEndLongPressOnLikeButton:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(commentCellDidEndLongPressOnLikeButton:),
                             capturedCell,
                             kSCIPostLikeConfirmBypassKey);
    }];
}

- (void)commentCellDidDoubleTap:(id)arg1 {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig(arg1);
        return;
    }
    __weak id weakSelf = self;
    id capturedCell = arg1;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction1(weakSelf,
                             @selector(commentCellDidDoubleTap:),
                             capturedCell,
                             kSCIPostLikeConfirmBypassKey);
    }];
}
%end

%hook IGFeedItemPreviewCommentCell
- (void)_didTapLikeButton {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig;
        return;
    }
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction(weakSelf,
                            @selector(_didTapLikeButton),
                            kSCIPostLikeConfirmBypassKey);
    }];
}
%end

// Story like/emoji confirmation is handled by SCIStoryInteractionPipeline.

%hook IGDirectThreadViewController
- (void)_didTapLikeButton {
    if (!sciShouldConfirmLike(self, kSCIPostLikeConfirmBypassKey, @"like_confirm")) {
        %orig;
        return;
    }
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayLikeAction(weakSelf,
                            @selector(_didTapLikeButton),
                            kSCIPostLikeConfirmBypassKey);
    }];
}
%end
