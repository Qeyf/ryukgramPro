#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCIPostCommentConfirmBypassKey = &kSCIPostCommentConfirmBypassKey;

static BOOL sciConsumePostCommentConfirmBypass(id target) {
    if (![objc_getAssociatedObject(target, kSCIPostCommentConfirmBypassKey) boolValue]) return NO;
    objc_setAssociatedObject(target,
                             kSCIPostCommentConfirmBypassKey,
                             nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayPostComment(id target) {
    if (!target) return;
    objc_setAssociatedObject(target,
                             kSCIPostCommentConfirmBypassKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, @selector(onSendButtonTap));
}

%hook IGCommentComposer.IGCommentComposerController
- (void)onSendButtonTap {
    if (sciConsumePostCommentConfirmBypass(self) ||
        ![SCIUtils getBoolPref:@"post_comment_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] Confirm post comment triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayPostComment(weakSelf);
    }];
}
%end
