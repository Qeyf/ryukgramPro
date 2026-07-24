#import "SCIRepostSheet.h"
#import "SCIInstagramComposerAutomation.h"
#import "../Utils.h"
#import <objc/runtime.h>

@interface SCIRepostSheet (SCIInternalComposerOverride)
+ (void)openInstagramCreatorWithLocalIdentifier:(NSString *)localIdentifier
                                         fileURL:(NSURL *)fileURL
                                      destination:(NSInteger)destination
                                          caption:(NSString *)caption;
@end

static void sciOpenInstagramCreatorInCurrentProcess(id self,
                                                     SEL _cmd,
                                                     NSString *localIdentifier,
                                                     NSURL *fileURL,
                                                     NSInteger destination,
                                                     NSString *caption) {
    (void)self;
    (void)_cmd;

    BOOL asReel = destination == 0;
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];

    [SCIInstagramComposerAutomation startWithLocalIdentifier:localIdentifier
                                                      asReel:asReel
                                                     caption:caption
                                                  completion:^(BOOL success, NSError *error) {
        if (success) {
            NSString *message = asReel
                ? SCILocalized(@"Reel sharing started in Instagram")
                : SCILocalized(@"Post sharing started in Instagram");
            [SCIUtils showToastForDuration:3.0 title:message];
            return;
        }

        NSString *description = error.localizedDescription ?: SCILocalized(@"Instagram composer automation failed");
        [SCIUtils showErrorHUDWithDescription:description];
        [SCIUtils showToastForDuration:4.0
                                 title:SCILocalized(@"Media remains in your gallery; no external share sheet was opened.")];
    }];
}

@implementation SCIRepostSheet (SCIInternalComposerOverride)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = @selector(openInstagramCreatorWithLocalIdentifier:fileURL:destination:caption:);
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
