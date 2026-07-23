#import "SCIRepostSheet.h"
#import "SCIMediaActions.h"
#import "../Utils.h"
#import "../Downloader/Download.h"
#import <Photos/Photos.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, SCIRepostDestination) {
    SCIRepostDestinationReel,
    SCIRepostDestinationFeedPost,
};

static NSString *sciNormalizedUsername(NSString *username) {
    if (![username isKindOfClass:[NSString class]] || !username.length) return nil;
    while ([username hasPrefix:@"@"]) username = [username substringFromIndex:1];
    return username.length ? username : nil;
}

static NSDictionary *sciFieldCache(id object) {
    if (!object) return nil;
    Ivar ivar = NULL;
    for (Class cls = [object class]; cls && !ivar; cls = class_getSuperclass(cls)) {
        ivar = class_getInstanceVariable(cls, "_fieldCache");
    }
    if (!ivar) return nil;

    id value = nil;
    @try { value = object_getIvar(object, ivar); }
    @catch (__unused NSException *exception) { return nil; }

    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *sciUsernameForMedia(id media) {
    if (!media) return nil;

    @try {
        id user = nil;
        @try { user = [media valueForKey:@"user"]; }
        @catch (__unused NSException *exception) {}

        if (!user) user = sciFieldCache(media)[@"user"];
        if (!user) return nil;

        NSString *username = nil;
        @try { username = [user valueForKey:@"username"]; }
        @catch (__unused NSException *exception) {}

        if (![username isKindOfClass:[NSString class]] || !username.length) {
            id cached = sciFieldCache(user)[@"username"];
            if ([cached isKindOfClass:[NSString class]]) {
                username = cached;
            } else if ([user isKindOfClass:[NSDictionary class]]) {
                id dictionaryValue = ((NSDictionary *)user)[@"username"];
                if ([dictionaryValue isKindOfClass:[NSString class]]) username = dictionaryValue;
            }
        }

        return sciNormalizedUsername(username);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *sciPreparedCaption(id media) {
    NSString *caption = media ? [SCIMediaActions captionForMedia:media] : nil;
    NSString *username = sciUsernameForMedia(media);
    NSString *credit = username.length ? [NSString stringWithFormat:@"cr: @%@", username] : nil;

    if (!caption.length) return credit ?: @"";
    if (!credit.length) return caption;

    if ([caption rangeOfString:credit options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return caption;
    }
    return [NSString stringWithFormat:@"%@\n\n%@", caption, credit];
}

static id sciObjectIvar(id object, const char *name) {
    if (!object || !name) return nil;

    Ivar ivar = NULL;
    for (Class cls = [object class]; cls && !ivar; cls = class_getSuperclass(cls)) {
        ivar = class_getInstanceVariable(cls, name);
    }
    if (!ivar) return nil;

    const char *type = ivar_getTypeEncoding(ivar);
    if (!type || type[0] != '@') return nil;

    @try { return object_getIvar(object, ivar); }
    @catch (__unused NSException *exception) { return nil; }
}

static BOOL sciURLsMatch(NSURL *left, NSURL *right) {
    if (!left || !right) return NO;
    if ([left isEqual:right]) return YES;
    if ([left.absoluteString isEqualToString:right.absoluteString]) return YES;

    NSURLComponents *leftComponents = [NSURLComponents componentsWithURL:left resolvingAgainstBaseURL:NO];
    NSURLComponents *rightComponents = [NSURLComponents componentsWithURL:right resolvingAgainstBaseURL:NO];
    leftComponents.query = nil;
    leftComponents.fragment = nil;
    rightComponents.query = nil;
    rightComponents.fragment = nil;
    return [leftComponents.URL.absoluteString isEqualToString:rightComponents.URL.absoluteString];
}

static BOOL sciMediaMatchesURL(id media, NSURL *targetURL) {
    if (!media || !targetURL) return NO;

    NSURL *videoURL = [SCIUtils getVideoUrlForMedia:(IGMedia *)media];
    NSURL *photoURL = [SCIUtils getPhotoUrlForMedia:(IGMedia *)media];
    if (sciURLsMatch(videoURL, targetURL) || sciURLsMatch(photoURL, targetURL)) return YES;

    if ([SCIMediaActions isCarouselMedia:media]) {
        for (id child in [SCIMediaActions carouselChildrenForMedia:media]) {
            NSURL *childVideoURL = [SCIUtils getVideoUrlForMedia:(IGMedia *)child];
            NSURL *childPhotoURL = [SCIUtils getPhotoUrlForMedia:(IGMedia *)child];
            if (sciURLsMatch(childVideoURL, targetURL) || sciURLsMatch(childPhotoURL, targetURL)) {
                return YES;
            }
        }
    }
    return NO;
}

static id sciMatchingMediaFromObject(id object, NSURL *targetURL) {
    if (!object || !targetURL) return nil;

    Class mediaClass = NSClassFromString(@"IGMedia");
    if ((mediaClass && [object isKindOfClass:mediaClass]) || [object respondsToSelector:@selector(mediaType)]) {
        if (sciMediaMatchesURL(object, targetURL)) return object;
    }

    static const char *const candidates[] = {
        "_mediaPassthrough", "_media", "_post", "_feedItem", "_item", "_currentMedia", "_video"
    };

    for (NSUInteger index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++) {
        id candidate = sciObjectIvar(object, candidates[index]);
        if (!candidate) continue;
        if (sciMediaMatchesURL(candidate, targetURL)) return candidate;
    }

    return nil;
}

static id sciFindMediaInViewTree(UIView *rootView, NSURL *targetURL) {
    if (!rootView || !targetURL) return nil;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:rootView];
    NSUInteger visited = 0;
    while (stack.count && visited < 6000) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        visited++;

        id media = sciMatchingMediaFromObject(view, targetURL);
        if (media) return media;

        for (UIView *subview in view.subviews) {
            [stack addObject:subview];
        }
    }
    return nil;
}

static UIViewController *sciPresentationController(void) {
    UIViewController *controller = topMostController();
    if (controller) return controller;

    UIApplication *application = [UIApplication sharedApplication];
    for (UIScene *scene in application.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive ||
            ![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isHidden || window.alpha <= 0.0) continue;
            controller = window.rootViewController;
            while (controller.presentedViewController) controller = controller.presentedViewController;
            if (controller) return controller;
        }
    }
    return nil;
}

static id sciResolveVisibleMedia(NSURL *targetURL) {
    UIViewController *controller = sciPresentationController();
    if (!controller || !targetURL) return nil;

    id media = sciMatchingMediaFromObject(controller, targetURL);
    if (media) return media;

    UIResponder *responder = controller;
    while (responder) {
        media = sciMatchingMediaFromObject(responder, targetURL);
        if (media) return media;
        responder = responder.nextResponder;
    }

    return sciFindMediaInViewTree(controller.view, targetURL);
}

static NSString *sciTemporaryExtension(NSURL *sourceURL, BOOL isVideo) {
    NSString *extension = sourceURL.pathExtension.lowercaseString;
    if (extension.length > 0 && extension.length <= 8) return extension;
    return isVideo ? @"mp4" : @"jpg";
}

@interface SCIRepostSheet ()
+ (void)presentDestinationPickerForMedia:(nullable id)media
                                videoURL:(nullable NSURL *)videoURL
                                photoURL:(nullable NSURL *)photoURL
                              sourceView:(nullable UIView *)sourceView;
+ (void)prepareMediaFromURL:(NSURL *)sourceURL
                    isVideo:(BOOL)isVideo
                       media:(nullable id)media
                 destination:(SCIRepostDestination)destination
                 sourceView:(nullable UIView *)sourceView;
+ (void)saveFileToPhotos:(NSURL *)fileURL
                 isVideo:(BOOL)isVideo
             destination:(SCIRepostDestination)destination
                  caption:(NSString *)caption
                     pill:(SCIDownloadPillView *)pill;
+ (void)openInstagramCreatorWithLocalIdentifier:(NSString *)localIdentifier
                                        fileURL:(NSURL *)fileURL
                                     destination:(SCIRepostDestination)destination
                                         caption:(NSString *)caption;
@end

@implementation SCIRepostSheet

+ (void)presentForMedia:(id)media fromView:(UIView *)sourceView {
    NSURL *videoURL = media ? [SCIUtils getVideoUrlForMedia:(IGMedia *)media] : nil;
    NSURL *photoURL = media ? [SCIUtils getPhotoUrlForMedia:(IGMedia *)media] : nil;
    [self presentDestinationPickerForMedia:media
                                  videoURL:videoURL
                                  photoURL:photoURL
                                sourceView:sourceView];
}

+ (void)repostWithVideoURL:(NSURL *)videoURL photoURL:(NSURL *)photoURL {
    NSURL *targetURL = videoURL ?: photoURL;
    id media = sciResolveVisibleMedia(targetURL);
    UIViewController *controller = sciPresentationController();
    [self presentDestinationPickerForMedia:media
                                  videoURL:videoURL
                                  photoURL:photoURL
                                sourceView:controller.view];
}

+ (void)presentDestinationPickerForMedia:(id)media
                                videoURL:(NSURL *)videoURL
                                photoURL:(NSURL *)photoURL
                              sourceView:(UIView *)sourceView {
    NSURL *sourceURL = videoURL ?: photoURL;
    if (!sourceURL) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"No media URL")];
        return;
    }

    UIViewController *controller = sciPresentationController();
    if (!controller) {
        [SCIUtils showErrorHUDWithDescription:SCILocalized(@"Unable to open creator")];
        return;
    }

    NSString *message = SCILocalized(@"The original caption and source credit will be copied. Only repost content you have permission to share.");
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:SCILocalized(@"Share as")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    __weak UIView *weakSourceView = sourceView;
    void (^selectDestination)(SCIRepostDestination) = ^(SCIRepostDestination destination) {
        [self prepareMediaFromURL:sourceURL
                         isVideo:(videoURL != nil)
                            media:media
                      destination:destination
                      sourceView:weakSourceView];
    };

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Reel")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        selectDestination(SCIRepostDestinationReel);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Feed post")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        selectDestination(SCIRepostDestinationFeedPost);
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:SCILocalized(@"Cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        UIView *anchor = sourceView ?: controller.view;
        popover.sourceView = anchor;
        popover.sourceRect = CGRectMake(CGRectGetMidX(anchor.bounds),
                                        CGRectGetMidY(anchor.bounds),
                                        1.0,
                                        1.0);
        popover.permittedArrowDirections = 0;
    }

    [controller presentViewController:sheet animated:YES completion:nil];
}

+ (void)prepareMediaFromURL:(NSURL *)sourceURL
                    isVideo:(BOOL)isVideo
                       media:(id)media
                 destination:(SCIRepostDestination)destination
                 sourceView:(UIView *)sourceView {
    NSString *preparedCaption = sciPreparedCaption(media);
    if (preparedCaption.length) {
        [UIPasteboard generalPasteboard].string = preparedCaption;
    }

    SCIDownloadPillView *pill = [SCIDownloadPillView shared];
    [pill resetState];
    [pill setText:SCILocalized(@"Preparing repost...")];
    [pill setSubtitle:preparedCaption.length ? SCILocalized(@"Caption copied") : nil];

    UIViewController *controller = sciPresentationController();
    UIView *hostView = sourceView.window ?: controller.view;
    if (hostView) [pill showInView:hostView];

    NSString *extension = sciTemporaryExtension(sourceURL, isVideo);
    NSURL *temporaryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"ryukgram_repost_%@.%@",
                                        [[NSUUID UUID] UUIDString],
                                        extension]]];

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.timeoutIntervalForRequest = 60.0;
    configuration.timeoutIntervalForResource = 300.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:sourceURL
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response
            : nil;
        BOOL validStatus = !httpResponse || (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300);

        if (error || !location || !validStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Download failed")];
                [pill dismissAfterDelay:2.0];
            });
            [session finishTasksAndInvalidate];
            return;
        }

        [[NSFileManager defaultManager] removeItemAtURL:temporaryURL error:nil];
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:temporaryURL error:&moveError];
        if (moveError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Save failed")];
                [pill dismissAfterDelay:2.0];
            });
            [session finishTasksAndInvalidate];
            return;
        }

        [session finishTasksAndInvalidate];
        [self saveFileToPhotos:temporaryURL
                       isVideo:isVideo
                   destination:destination
                        caption:preparedCaption
                          pill:pill];
    }];
    [task resume];
}

+ (void)saveFileToPhotos:(NSURL *)fileURL
                 isVideo:(BOOL)isVideo
             destination:(SCIRepostDestination)destination
                  caption:(NSString *)caption
                     pill:(SCIDownloadPillView *)pill {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                               handler:^(PHAuthorizationStatus status) {
        BOOL authorized = status == PHAuthorizationStatusAuthorized ||
                          status == PHAuthorizationStatusLimited;
        if (!authorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [pill showError:SCILocalized(@"Photos access denied")];
                [pill dismissAfterDelay:2.0];
            });
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            return;
        }

        __block NSString *localIdentifier = nil;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            PHAssetResourceCreationOptions *options = [PHAssetResourceCreationOptions new];
            options.shouldMoveFile = NO;
            [request addResourceWithType:(isVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto)
                                 fileURL:fileURL
                                 options:options];
            localIdentifier = request.placeholderForCreatedAsset.localIdentifier;
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success || error || !localIdentifier.length) {
                    [pill showError:SCILocalized(@"Failed to save")];
                    [pill dismissAfterDelay:2.0];
                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                    return;
                }

                NSString *destinationName = destination == SCIRepostDestinationReel
                    ? SCILocalized(@"Reel")
                    : SCILocalized(@"Feed post");
                [pill showSuccess:SCILocalized(@"Opening creator...")];
                [pill setSubtitle:[NSString stringWithFormat:SCILocalized(@"%@ selected"), destinationName]];
                [pill dismissAfterDelay:1.0];

                [self openInstagramCreatorWithLocalIdentifier:localIdentifier
                                                     fileURL:fileURL
                                                  destination:destination
                                                      caption:caption];
            });
        }];
    }];
}

+ (void)openInstagramCreatorWithLocalIdentifier:(NSString *)localIdentifier
                                        fileURL:(NSURL *)fileURL
                                     destination:(SCIRepostDestination)destination
                                         caption:(NSString *)caption {
    if (caption.length) [UIPasteboard generalPasteboard].string = caption;

    NSString *encodedIdentifier = [localIdentifier
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *URLString = [NSString stringWithFormat:
        @"instagram://library?OpenInEditor=1&LocalIdentifier=%@", encodedIdentifier ?: @""];
    NSURL *creatorURL = [NSURL URLWithString:URLString];

    UIApplication *application = [UIApplication sharedApplication];
    if (creatorURL && [application canOpenURL:creatorURL]) {
        [application openURL:creatorURL options:@{} completionHandler:^(BOOL success) {
            if (success) {
                [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                NSString *hint = destination == SCIRepostDestinationReel
                    ? SCILocalized(@"Choose Reels in the Instagram creator, then paste the prepared caption.")
                    : SCILocalized(@"Choose Post in the Instagram creator, then paste the prepared caption.");
                [SCIUtils showToastForDuration:3.0 title:hint];
            } else {
                [SCIUtils showShareVC:fileURL];
            }
        }];
        return;
    }

    [SCIUtils showShareVC:fileURL];
}

@end
