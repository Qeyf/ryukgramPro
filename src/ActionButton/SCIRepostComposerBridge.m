#import "SCIRepostSheet.h"
#import "SCIInstagramComposerAutomation.h"
#import "../Utils.h"
#import <objc/runtime.h>

static NSURL *sciCompatibilityCreatorURL(NSString *localIdentifier) {
    if (localIdentifier.length == 0) return nil;
    NSString *encodedIdentifier = [localIdentifier
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (encodedIdentifier.length == 0) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:
        @"instagram://library?OpenInEditor=1&LocalIdentifier=%@", encodedIdentifier]];
}

static void sciOpenCompatibilityCreatorOrShare(NSString *localIdentifier,
                                                NSURL *fileURL,
                                                BOOL asReel,
                                                NSString *failureDescription) {
    NSURL *creatorURL = sciCompatibilityCreatorURL(localIdentifier);
    UIApplication *application = [UIApplication sharedApplication];

    void (^openShareFallback)(void) = ^{
        NSLog(@"[RyukGram][Repost] Native creator URL failed; opening final share-sheet fallback");
        [SCIUtils showErrorHUDWithDescription:failureDescription ?: SCILocalized(@"Instagram composer automation failed")];
        if (fileURL && [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
            [SCIUtils showShareVC:fileURL];
        } else {
            [SCIUtils showToastForDuration:4.0 title:SCILocalized(@"Media remains in your gallery.")];
        }
    };

    if (!creatorURL) {
        openShareFallback();
        return;
    }

    [application openURL:creatorURL options:@{} completionHandler:^(BOOL opened) {
        if (!opened) {
            openShareFallback();
            return;
        }

        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
        NSString *hint = asReel
            ? SCILocalized(@"Choose Reels in the Instagram creator, then paste the prepared caption.")
            : SCILocalized(@"Choose Post in the Instagram creator, then paste the prepared caption.");
        [SCIUtils showToastForDuration:3.0 title:hint];
        NSLog(@"[RyukGram][Repost] Opened Instagram creator through LocalIdentifier compatibility URL");
    }];
}

static void sciOpenInstagramCreatorInCurrentProcess(id self,
                                                     SEL _cmd,
                                                     NSString *localIdentifier,
                                                     NSURL *fileURL,
                                                     NSInteger destination,
                                                     NSString *caption) {
    (void)self;
    (void)_cmd;

    BOOL asReel = destination == 0;

    // Keep the downloaded file until either the in-process automation or the
    // compatibility URL succeeds. The previous bridge deleted it before the
    // creator opened, leaving no usable final fallback when Instagram 434's
    // SwiftUI floating create control could not be activated.
    [SCIInstagramComposerAutomation startWithLocalIdentifier:localIdentifier
                                                      asReel:asReel
                                                     caption:caption
                                                  completion:^(BOOL success, NSError *error) {
        if (success) {
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            NSString *message = asReel
                ? SCILocalized(@"Reel sharing started in Instagram")
                : SCILocalized(@"Post sharing started in Instagram");
            [SCIUtils showToastForDuration:3.0 title:message];
            return;
        }

        NSString *description = error.localizedDescription ?: SCILocalized(@"Instagram composer automation failed");
        NSLog(@"[RyukGram][Repost] In-process creator failed: %@; trying LocalIdentifier URL", description);
        sciOpenCompatibilityCreatorOrShare(localIdentifier, fileURL, asReel, description);
    }];
}

@implementation SCIRepostSheet (SCIInternalComposerOverride)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = NSSelectorFromString(@"openInstagramCreatorWithLocalIdentifier:fileURL:destination:caption:");
        Method method = class_getClassMethod(self, selector);
        if (!method) {
            NSLog(@"[RyukGram][Repost] Internal creator bridge could not find %@", NSStringFromSelector(selector));
            return;
        }
        method_setImplementation(method, (IMP)sciOpenInstagramCreatorInCurrentProcess);
        NSLog(@"[RyukGram][Repost] Installed in-process Instagram composer bridge");
    });
}

@end
