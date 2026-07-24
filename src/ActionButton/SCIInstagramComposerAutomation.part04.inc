            [self handleAdvancingEditor];
            break;
        case SCIComposerAutomationPhaseFillingCaption:
            [self handleFillingCaption];
            break;
        case SCIComposerAutomationPhasePublishing:
            [self handlePublishing];
            break;
        case SCIComposerAutomationPhaseWaitingForCompletion:
            [self handleWaitingForCompletion];
            break;
    }
}

- (void)handleOpeningCreate {
    if (sciLooksLikeComposer() || sciCaptionInput()) {
        [self advanceToPhase:SCIComposerAutomationPhaseSelectingDestination delay:0.35];
        return;
    }

    if (![self canPerformAction]) {
        [self scheduleTickAfter:0.25];
        return;
    }

    if (!self.didInvokeCreateSelector) {
        id floatingCreateAction = sciInstagram434FloatingCreateAction();
        if (floatingCreateAction && sciActivateActionObject(floatingCreateAction)) {
            self.didInvokeCreateSelector = YES;
            self.lastActionTime = CACurrentMediaTime();
            NSLog(@"[RyukGram][Repost] Activated Instagram 434 SwiftUI floating create action");
            [self scheduleTickAfter:0.95];
            return;
        }

        UIView *createButton = sciBestActionForTokens(@[@"create", @"create new", @"new post", @"new reel", @"add", @"olustur", @"oluştur", @"yeni gonderi", @"yeni gönderi", @"plus", @"+"],
                                                        @[@"creation", @"create", @"tabbar", @"header", @"floatingbar", @"plus"],
                                                        NO);
        if (createButton && sciActivateView(createButton)) {
            self.didInvokeCreateSelector = YES;
            self.lastActionTime = CACurrentMediaTime();
            NSLog(@"[RyukGram][Repost] Activated visible Instagram create control %@", NSStringFromClass(createButton.class));
            [self scheduleTickAfter:0.95];
            return;
        }

        if (sciInvokeKnownCreateSelector()) {
            self.didInvokeCreateSelector = YES;
            self.lastActionTime = CACurrentMediaTime();
            [self scheduleTickAfter:0.95];
            return;
        }
    }

    if (!self.didInvokeCreatorDeepLink && self.phaseAttempts >= 4) {
        self.didInvokeCreatorDeepLink = YES;
        self.lastActionTime = CACurrentMediaTime();
        __weak typeof(self) weakSelf = self;
        sciOpenInstagramLibraryCreator(self.localIdentifier, ^(BOOL opened) {
            SCIInstagramComposerAutomation *automation = weakSelf;
            if (!automation || sciActiveComposerAutomation != automation) return;
            automation.lastActionTime = CACurrentMediaTime();
            if (opened) {
                [SCIUtils showToastForDuration:2.0 title:SCILocalized(@"Opening creator...")];
                [automation scheduleTickAfter:1.15];
            } else {
                [automation scheduleTickAfter:0.45];
            }
        });
        return;
    }

    if (self.phaseAttempts > 24) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorUnableToOpenComposer description:@"Could not open Instagram's in-app creator"];
        return;
    }
    [self scheduleTickAfter:0.45];
}

- (NSArray<NSString *> *)destinationTokens {
    return self.asReel
        ? @[@"reel", @"reels", @"create reel", @"new reel", @"reel olustur", @"reel oluştur"]
        : @[@"post", @"new post", @"feed post", @"gonderi", @"gönderi", @"yeni gonderi", @"yeni gönderi"];
}

- (void)handleSelectingDestination {
    if (sciCaptionInput()) {
        [self advanceToPhase:SCIComposerAutomationPhaseFillingCaption delay:0.25];
        return;
    }

    UICollectionViewCell *matchingCell = sciCellMatchingAsset(self.localIdentifier);
    if (matchingCell || sciFirstLikelyMediaCell()) {
        [self advanceToPhase:SCIComposerAutomationPhaseSelectingAsset delay:0.25];
        return;
    }

    if (![self canPerformAction]) {
        [self scheduleTickAfter:0.25];
        return;
    }

    UIView *destinationAction = sciBestActionForTokens([self destinationTokens],
                                                        @[@"creation", @"destination", @"gallery", @"tab", @"menu", @"action"],
                                                        YES);
    if (destinationAction && sciActivateView(destinationAction)) {
        self.didTapDestinationMode = YES;
        self.lastActionTime = CACurrentMediaTime();
        [self advanceToPhase:SCIComposerAutomationPhaseSelectingAsset delay:0.8];
        return;
    }

    if (self.phaseAttempts > 10 && sciLooksLikeComposer()) {
        [self advanceToPhase:SCIComposerAutomationPhaseSelectingAsset delay:0.25];
        return;
    }
    if (self.phaseAttempts > 18) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorUnableToChooseDestination description:@"Could not choose Reel or Post in Instagram"];
        return;
    }
    [self scheduleTickAfter:0.45];
}

- (void)handleSelectingAsset {
    if (sciCaptionInput()) {
        [self advanceToPhase:SCIComposerAutomationPhaseFillingCaption delay:0.25];
        return;
    }

    if (![self canPerformAction]) {
        [self scheduleTickAfter:0.25];
        return;
    }

    if (!self.didTapDestinationMode) {
        UIView *modeAction = sciBestActionForTokens([self destinationTokens],
                                                    @[@"destination", @"gallery", @"tab", @"segmented"],
                                                    YES);
        if (modeAction && sciActivateView(modeAction)) {
            self.didTapDestinationMode = YES;
            self.lastActionTime = CACurrentMediaTime();
            [self scheduleTickAfter:0.65];
            return;
        }
    }

    UICollectionViewCell *cell = sciCellMatchingAsset(self.localIdentifier);
    if (!cell && self.phaseAttempts >= 5) cell = sciFirstLikelyMediaCell();
    if (cell && sciActivateView(cell)) {
        self.didSelectAsset = YES;
        self.lastActionTime = CACurrentMediaTime();
        [self advanceToPhase:SCIComposerAutomationPhaseAdvancingEditor delay:0.75];
        return;
    }

    if (self.phaseAttempts > 24) {
        [self finishWithSuccess:NO code:SCIComposerAutomationErrorUnableToSelectAsset description:@"Saved media was not found in Instagram's gallery"];
        return;
    }
    [self scheduleTickAfter:0.45];
}

- (void)handleAdvancingEditor {
    UIView *captionInput = sciCaptionInput();
    if (captionInput) {
        [self advanceToPhase:SCIComposerAutomationPhaseFillingCaption delay:0.2];
        return;
    }

    UIView *shareButton = sciBestActionForTokens(@[@"share", @"share now", @"publish", @"paylas", @"paylaş", @"yayinla", @"yayınla"],
                                                  @[@"creation", @"actionbar", @"button"],
