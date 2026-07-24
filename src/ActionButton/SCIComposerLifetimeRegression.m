#import <Foundation/Foundation.h>

// Build-time regression guard for the Instagram composer terminal path.
//
// The production automation is intentionally split into .inc files because of
// Logos/Theos source-size constraints. This compilation unit documents the ARC
// lifetime requirement that prevented the Instagram 434 objc_msgSend crash:
// copy the callback while the owner is alive, clear instance state, then release
// the global owner. Keeping this helper compilable under the same ARC flags
// protects the objc_precise_lifetime construct used by the real implementation.
__attribute__((unused))
static void SCIValidateComposerCompletionLifetimePattern(id owner,
                                                         void (^callback)(BOOL, NSError *)) {
    __attribute__((objc_precise_lifetime)) id preciseOwner = owner;
    void (^copiedCallback)(BOOL, NSError *) = [callback copy];
    (void)preciseOwner;
    if (copiedCallback) copiedCallback(YES, nil);
}
