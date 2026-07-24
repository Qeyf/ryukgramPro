#import "SCIFFmpeg.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// Standalone RyukGram.dylib releases intentionally contain only the tweak
// binary. FFmpegKit remains an optional enhancement when its framework bundle
// is installed next to the dylib or in a supported jailbreak resource path.
//
// The original +isAvailable implementation displays an intrusive diagnostic
// alert when no framework is present. Detect that normal standalone state
// before calling it so Instagram can finish launching and the action buttons
// remain available.

static BOOL (*sciOriginalFFmpegIsAvailable)(id, SEL) = NULL;

static NSString *sciStandaloneDylibDirectory(void) {
    Dl_info info;
    if (dladdr((const void *)sciStandaloneDylibDirectory, &info) && info.dli_fname) {
        return [[[NSString alloc] initWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
    }
    return nil;
}

static BOOL sciFFmpegKitBinaryExists(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    NSString *dylibDirectory = sciStandaloneDylibDirectory();
    if (dylibDirectory.length) {
        [paths addObject:[dylibDirectory stringByAppendingPathComponent:@"ffmpegkit.framework/ffmpegkit"]];
    }

    NSString *appRoot = [NSBundle mainBundle].bundlePath;
    NSString *frameworks = [NSBundle mainBundle].privateFrameworksPath;
    if (appRoot.length) {
        [paths addObject:[appRoot stringByAppendingPathComponent:@"RyukGram.bundle/ffmpegkit.framework/ffmpegkit"]];
    }
    if (frameworks.length) {
        [paths addObject:[frameworks stringByAppendingPathComponent:@"ffmpegkit.framework/ffmpegkit"]];
    }

    [paths addObjectsFromArray:@[
        @"/var/jb/Library/Application Support/RyukGram.bundle/ffmpegkit.framework/ffmpegkit",
        @"/var/jb/Library/MobileSubstrate/DynamicLibraries/ffmpegkit.framework/ffmpegkit",
        @"/Library/Application Support/RyukGram.bundle/ffmpegkit.framework/ffmpegkit",
        @"/Library/MobileSubstrate/DynamicLibraries/ffmpegkit.framework/ffmpegkit"
    ]];

    for (NSString *path in paths) {
        if ([fileManager isExecutableFileAtPath:path] || [fileManager fileExistsAtPath:path]) {
            return YES;
        }
    }
    return NO;
}

static BOOL sciStandaloneFFmpegIsAvailable(id self, SEL selector) {
    if (!sciFFmpegKitBinaryExists()) {
        return NO;
    }
    return sciOriginalFFmpegIsAvailable
        ? sciOriginalFFmpegIsAvailable(self, selector)
        : NO;
}

@implementation SCIFFmpeg (SCIStandaloneDylibGuard)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method method = class_getClassMethod(self, @selector(isAvailable));
        if (!method) return;

        sciOriginalFFmpegIsAvailable = (void *)method_getImplementation(method);
        method_setImplementation(method, (IMP)sciStandaloneFFmpegIsAvailable);
        NSLog(@"[RyukGram] Standalone dylib FFmpegKit guard installed");
    });
}

@end
