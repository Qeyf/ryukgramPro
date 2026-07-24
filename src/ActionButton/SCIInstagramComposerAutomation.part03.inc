        NSMutableArray<UIViewController *> *queue = [NSMutableArray arrayWithObject:root];
        NSUInteger visited = 0;
        while (queue.count && visited < 200) {
            UIViewController *controller = queue.firstObject;
            [queue removeObjectAtIndex:0];
            visited++;
            if (![result containsObject:controller]) [result addObject:controller];
            if (controller.presentedViewController) [queue addObject:controller.presentedViewController];
            for (UIViewController *child in controller.childViewControllers) [queue addObject:child];
            if ([controller isKindOfClass:[UINavigationController class]]) {
                for (UIViewController *child in ((UINavigationController *)controller).viewControllers) [queue addObject:child];
            }
            if ([controller isKindOfClass:[UITabBarController class]]) {
                for (UIViewController *child in ((UITabBarController *)controller).viewControllers) [queue addObject:child];
            }
        }
    }
    return result;
}

static BOOL sciInvokeKnownCreateSelector(void) {
    NSArray<NSString *> *selectors = @[
        @"_creationButtonPressed", @"creationButtonPressed", @"_createButtonPressed", @"createButtonPressed",
        @"_didTapCreationButton", @"didTapCreationButton", @"_didTapCreateButton", @"didTapCreateButton",
        @"_onCreationButtonTapped", @"onCreationButtonTapped", @"_onCreateButtonTapped", @"onCreateButtonTapped",
        @"_onNewPostButtonTapped", @"onNewPostButtonTapped", @"_newPostButtonPressed", @"newPostButtonPressed",
        @"_didTapCreationTab", @"didTapCreationTab", @"_creationTabTapped", @"creationTabTapped",
        @"_openCreationFlow", @"openCreationFlow", @"_presentCreationFlow", @"presentCreationFlow",
        @"_showCreationFlow", @"showCreationFlow", @"_openComposer", @"openComposer",
        @"_presentComposer", @"presentComposer", @"_didPressCreate", @"didPressCreate"
    ];
    for (UIViewController *controller in sciControllerCandidates()) {
        for (NSString *selectorName in selectors) {
            SEL noArgumentSelector = NSSelectorFromString(selectorName);
            if ([controller respondsToSelector:noArgumentSelector]) {
                @try {
                    ((void(*)(id, SEL))objc_msgSend)(controller, noArgumentSelector);
                    NSLog(@"[RyukGram][Repost] Opened creation flow via %@ %@", NSStringFromClass(controller.class), selectorName);
                    return YES;
                } @catch (__unused NSException *exception) {}
            }
            SEL oneArgumentSelector = NSSelectorFromString([selectorName stringByAppendingString:@":"]);
            if ([controller respondsToSelector:oneArgumentSelector]) {
                @try {
                    ((void(*)(id, SEL, id))objc_msgSend)(controller, oneArgumentSelector, nil);
                    NSLog(@"[RyukGram][Repost] Opened creation flow via %@ %@:", NSStringFromClass(controller.class), selectorName);
                    return YES;
                } @catch (__unused NSException *exception) {}
            }
        }
    }
    return NO;
}

static NSURL *sciInstagramLibraryCreatorURL(NSString *localIdentifier) {
    if (localIdentifier.length == 0) return nil;
    NSString *encodedIdentifier = [localIdentifier
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (encodedIdentifier.length == 0) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:
        @"instagram://library?OpenInEditor=1&LocalIdentifier=%@", encodedIdentifier]];
}

static void sciOpenInstagramLibraryCreator(NSString *localIdentifier,
                                           void (^completion)(BOOL opened)) {
    NSURL *creatorURL = sciInstagramLibraryCreatorURL(localIdentifier);
    if (!creatorURL) {
        if (completion) completion(NO);
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    [application openURL:creatorURL options:@{} completionHandler:^(BOOL opened) {
        NSLog(@"[RyukGram][Repost] Instagram library creator deep link %@",
              opened ? @"opened" : @"failed");
        if (completion) completion(opened);
    }];
}

static BOOL sciLooksLikeComposer(void) {
    UIViewController *controller = sciTopController();
    NSString *controllerName = sciNormalizedText(NSStringFromClass(controller.class));
    if (sciTextContainsAny(controllerName, @[@"creation", @"composer", @"gallery", @"picker", @"camera", @"postcapture", @"sundialcreation", @"assetpicker"])) return YES;
    for (UIView *view in sciVisibleViews()) {
        NSString *className = sciNormalizedText(NSStringFromClass(view.class));
        if (sciTextContainsAny(className, @[@"creation", @"gallery", @"mediapicker", @"assetpicker", @"postcapture", @"composer"])) return YES;
    }
    return NO;
}

@implementation SCIInstagramComposerAutomation

+ (BOOL)isRunning {
    return sciActiveComposerAutomation != nil;
}

+ (void)cancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        SCIInstagramComposerAutomation *automation = sciActiveComposerAutomation;
        if (!automation) return;
        [automation finishWithSuccess:NO code:SCIComposerAutomationErrorCancelled description:@"Repost automation cancelled"];
    });
}

+ (void)startWithLocalIdentifier:(NSString *)localIdentifier
                          asReel:(BOOL)asReel
                         caption:(NSString *)caption
                      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sciActiveComposerAutomation) {
            [sciActiveComposerAutomation finishWithSuccess:NO
                                                       code:SCIComposerAutomationErrorCancelled
                                                description:@"Replaced by a new repost operation"];
        }

        SCIInstagramComposerAutomation *automation = [SCIInstagramComposerAutomation new];
        automation.localIdentifier = [localIdentifier copy];
        automation.caption = [caption copy] ?: @"";
        automation.asReel = asReel;
        automation.phase = SCIComposerAutomationPhaseOpeningCreate;
        automation.deadline = CACurrentMediaTime() + 105.0;
        automation.completion = [completion copy];
        sciActiveComposerAutomation = automation;

        [UIPasteboard generalPasteboard].string = automation.caption.length ? automation.caption : nil;
        [SCIUtils showToastForDuration:2.0 title:SCILocalized(@"Preparing Instagram composer...")];
        [automation scheduleTickAfter:0.35];
    });
}

- (void)scheduleTickAfter:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf tick];
    });
}

- (void)advanceToPhase:(SCIComposerAutomationPhase)phase delay:(NSTimeInterval)delay {
    self.phase = phase;
    self.phaseAttempts = 0;
    self.lastActionTime = CACurrentMediaTime();
    [self scheduleTickAfter:delay];
}

- (BOOL)canPerformAction {
    return CACurrentMediaTime() - self.lastActionTime >= 0.65;
}

- (void)tick {
    if (sciActiveComposerAutomation != self) return;
    if (CACurrentMediaTime() > self.deadline) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorTimedOut description:@"Instagram composer automation timed out"];
        return;
    }

    self.totalAttempts += 1;
    self.phaseAttempts += 1;

    switch (self.phase) {
        case SCIComposerAutomationPhaseOpeningCreate:
            [self handleOpeningCreate];
            break;
        case SCIComposerAutomationPhaseSelectingDestination:
            [self handleSelectingDestination];
            break;
        case SCIComposerAutomationPhaseSelectingAsset:
            [self handleSelectingAsset];
            break;
        case SCIComposerAutomationPhaseAdvancingEditor:
