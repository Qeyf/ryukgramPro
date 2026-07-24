                                                  YES);
    if (shareButton && self.caption.length == 0) {
        [self advanceToPhase:SCIComposerAutomationPhasePublishing delay:0.2];
        return;
    }

    if (![self canPerformAction]) {
        [self scheduleTickAfter:0.25];
        return;
    }

    UIView *nextButton = sciBestActionForTokens(@[@"next", @"continue", @"ileri", @"devam"],
                                                 @[@"creation", @"actionbar", @"button", @"navigation"],
                                                 YES);
    if (nextButton && sciActivateView(nextButton)) {
        self.lastActionTime = CACurrentMediaTime();
        self.phaseAttempts = 0;
        [self scheduleTickAfter:0.8];
        return;
    }

    if (shareButton) {
        [self advanceToPhase:SCIComposerAutomationPhaseFillingCaption delay:0.2];
        return;
    }

    if (self.phaseAttempts > 30) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorUnableToAdvance description:@"Instagram's Next button was not found"];
        return;
    }
    [self scheduleTickAfter:0.45];
}

- (void)handleFillingCaption {
    UIView *input = sciCaptionInput();
    if (!input) {
        if (self.phaseAttempts > 10) {
            [self advanceToPhase:SCIComposerAutomationPhasePublishing delay:0.2];
            return;
        }
        [self scheduleTickAfter:0.35];
        return;
    }

    if (!self.didSetCaption) {
        self.didSetCaption = sciSetCaptionOnInput(input, self.caption);
        [UIPasteboard generalPasteboard].string = self.caption.length ? self.caption : nil;
        self.lastActionTime = CACurrentMediaTime();
        [self advanceToPhase:SCIComposerAutomationPhasePublishing delay:0.7];
        return;
    }
    [self advanceToPhase:SCIComposerAutomationPhasePublishing delay:0.2];
}

- (void)handlePublishing {
    if (![self canPerformAction]) {
        [self scheduleTickAfter:0.25];
        return;
    }

    UIView *shareButton = sciBestActionForTokens(@[@"share", @"share now", @"publish", @"paylas", @"paylaş", @"yayinla", @"yayınla"],
                                                  @[@"creation", @"actionbar", @"button", @"navigation"],
                                                  YES);
    if (shareButton && sciActivateView(shareButton)) {
        self.didTapShare = YES;
        self.lastActionTime = CACurrentMediaTime();
        [self advanceToPhase:SCIComposerAutomationPhaseWaitingForCompletion delay:1.5];
        return;
    }

    if (self.phaseAttempts > 24) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorUnableToPublish description:@"Instagram's Share button was not found or remained disabled"];
        return;
    }
    [self scheduleTickAfter:0.45];
}

- (void)handleWaitingForCompletion {
    if (!sciLooksLikeComposer()) {
        [self finishWithSuccess:YES code:0 description:nil];
        return;
    }

    NSString *allText = @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (UIView *view in sciVisibleViews()) {
        NSString *text = sciTextForView(view);
        if (text.length) [parts addObject:text];
    }
    allText = [parts componentsJoinedByString:@" "];
    if (sciTextContainsAny(allText, @[@"your reel is being shared", @"your post is being shared", @"sharing", @"paylasiliyor", @"paylaşılıyor", @"gonderiliyor", @"gönderiliyor"])) {
        [self finishWithSuccess:YES code:0 description:nil];
        return;
    }

    if (self.phaseAttempts > 20) {
        [self finishWithSuccess:YES code:0 description:nil];
        return;
    }
    [self scheduleTickAfter:0.6];
}

- (void)finishWithSuccess:(BOOL)success code:(NSInteger)code description:(NSString *)description {
    if (sciActiveComposerAutomation != self) return;
    sciActiveComposerAutomation = nil;
    void (^completion)(BOOL, NSError *) = self.completion;
    self.completion = nil;

    NSError *error = nil;
    if (!success) {
        error = [NSError errorWithDomain:SCIComposerAutomationErrorDomain
                                   code:code
                               userInfo:@{NSLocalizedDescriptionKey: description ?: @"Instagram composer automation failed"}];
        NSLog(@"[RyukGram][Repost] Composer automation failed (%ld): %@", (long)code, error.localizedDescription);
    } else {
        NSLog(@"[RyukGram][Repost] Composer automation completed");
    }
    if (completion) completion(success, error);
}

@end
