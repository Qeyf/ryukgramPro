#import "SCIInstagramComposerAutomation.h"
#import "../Utils.h"
#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const SCIComposerAutomationErrorDomain = @"com.ryukgram.composer-automation";

typedef NS_ENUM(NSInteger, SCIComposerAutomationErrorCode) {
    SCIComposerAutomationErrorCancelled = 1,
    SCIComposerAutomationErrorTimedOut,
    SCIComposerAutomationErrorUnableToOpenComposer,
    SCIComposerAutomationErrorUnableToChooseDestination,
    SCIComposerAutomationErrorUnableToSelectAsset,
    SCIComposerAutomationErrorUnableToAdvance,
    SCIComposerAutomationErrorUnableToPublish,
};

typedef NS_ENUM(NSInteger, SCIComposerAutomationPhase) {
    SCIComposerAutomationPhaseOpeningCreate,
    SCIComposerAutomationPhaseSelectingDestination,
    SCIComposerAutomationPhaseSelectingAsset,
    SCIComposerAutomationPhaseAdvancingEditor,
    SCIComposerAutomationPhaseFillingCaption,
    SCIComposerAutomationPhasePublishing,
    SCIComposerAutomationPhaseWaitingForCompletion,
};

@interface SCIInstagramComposerAutomation ()
@property (nonatomic, copy) NSString *localIdentifier;
@property (nonatomic, copy) NSString *caption;
@property (nonatomic, assign) BOOL asReel;
@property (nonatomic, assign) SCIComposerAutomationPhase phase;
@property (nonatomic, assign) NSInteger phaseAttempts;
@property (nonatomic, assign) NSInteger totalAttempts;
@property (nonatomic, assign) CFTimeInterval deadline;
@property (nonatomic, assign) BOOL didTapDestinationMode;
@property (nonatomic, assign) BOOL didSelectAsset;
@property (nonatomic, assign) BOOL didSetCaption;
@property (nonatomic, assign) BOOL didTapShare;
@property (nonatomic, assign) BOOL didInvokeCreateSelector;
@property (nonatomic, assign) BOOL didInvokeCreatorDeepLink;
@property (nonatomic, assign) CFTimeInterval lastActionTime;
@property (nonatomic, copy) void (^completion)(BOOL success, NSError * _Nullable error);
@end

static SCIInstagramComposerAutomation *sciActiveComposerAutomation = nil;

static NSString *sciNormalizedText(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return @"";
    NSString *folded = [value stringByFoldingWithOptions:(NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch)
                                                   locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return folded.lowercaseString;
}

static BOOL sciViewIsVisible(UIView *view) {
    if (!view || view.hidden || view.alpha < 0.02 || !view.window) return NO;
    if (CGRectIsEmpty(view.bounds) || CGRectGetWidth(view.bounds) < 1.0 || CGRectGetHeight(view.bounds) < 1.0) return NO;
    return YES;
}

static NSArray<UIWindow *> *sciForegroundWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    UIApplication *application = [UIApplication sharedApplication];
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]] ||
            scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden && window.alpha > 0.0) [windows addObject:window];
        }
    }
    if (windows.count == 0 && application.keyWindow) [windows addObject:application.keyWindow];
    [windows sortUsingComparator:^NSComparisonResult(UIWindow *left, UIWindow *right) {
        if (left.windowLevel > right.windowLevel) return NSOrderedAscending;
        if (left.windowLevel < right.windowLevel) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return windows;
}

static UIViewController *sciTopControllerFrom(UIViewController *controller) {
    if (!controller) return nil;
    UIViewController *current = controller;
    while (YES) {
        UIViewController *next = current.presentedViewController;
        if (!next && [current isKindOfClass:[UINavigationController class]]) {
            next = ((UINavigationController *)current).visibleViewController;
        }
        if (!next && [current isKindOfClass:[UITabBarController class]]) {
            next = ((UITabBarController *)current).selectedViewController;
        }
        if (!next || next == current) break;
        current = next;
    }
    return current;
}

static UIViewController *sciTopController(void) {
    for (UIWindow *window in sciForegroundWindows()) {
        UIViewController *controller = sciTopControllerFrom(window.rootViewController);
        if (controller) return controller;
    }
    return nil;
}

static NSArray<UIView *> *sciVisibleViews(void) {
    NSMutableArray<UIView *> *result = [NSMutableArray array];
    NSMutableArray<UIView *> *stack = [NSMutableArray array];
    for (UIWindow *window in sciForegroundWindows()) {
        [stack addObject:window];
    }
    NSUInteger visited = 0;
    while (stack.count && visited < 10000) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        visited++;
        if (!sciViewIsVisible(view) && ![view isKindOfClass:[UIWindow class]]) continue;
        [result addObject:view];
        for (UIView *subview in view.subviews.reverseObjectEnumerator) {
            [stack addObject:subview];
        }
    }
    return result;
}

static NSString *sciImageNameForButton(UIButton *button) {
    UIImage *image = [button imageForState:UIControlStateNormal] ?: button.currentImage;
    if (!image) return nil;
    SEL imageNameSelector = NSSelectorFromString(@"ig_imageName");
    if ([image respondsToSelector:imageNameSelector]) {
        @try {
            id name = ((id(*)(id, SEL))objc_msgSend)(image, imageNameSelector);
            if ([name isKindOfClass:[NSString class]]) return name;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}
