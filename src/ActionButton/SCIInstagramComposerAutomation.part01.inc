
static NSString *sciTextForView(UIView *view) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *label = view.accessibilityLabel;
    NSString *identifier = view.accessibilityIdentifier;
    NSString *value = [view.accessibilityValue isKindOfClass:[NSString class]] ? (NSString *)view.accessibilityValue : nil;
    if (label.length) [parts addObject:label];
    if (identifier.length) [parts addObject:identifier];
    if (value.length) [parts addObject:value];

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        NSString *title = [button titleForState:UIControlStateNormal] ?: button.currentTitle;
        NSString *imageName = sciImageNameForButton(button);
        if (title.length) [parts addObject:title];
        if (imageName.length) [parts addObject:imageName];
    } else if ([view isKindOfClass:[UILabel class]]) {
        NSString *text = ((UILabel *)view).text;
        if (text.length) [parts addObject:text];
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *field = (UITextField *)view;
        if (field.placeholder.length) [parts addObject:field.placeholder];
        if (field.text.length) [parts addObject:field.text];
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length) [parts addObject:textView.text];
    }

    return sciNormalizedText([parts componentsJoinedByString:@" "]);
}

static BOOL sciTextContainsAny(NSString *text, NSArray<NSString *> *tokens) {
    if (text.length == 0) return NO;
    for (NSString *token in tokens) {
        NSString *normalizedToken = sciNormalizedText(token);
        if (normalizedToken.length && [text containsString:normalizedToken]) return YES;
    }
    return NO;
}

static BOOL sciTextExactlyMatchesAny(NSString *text, NSArray<NSString *> *tokens) {
    if (text.length == 0) return NO;
    NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmed = [text stringByTrimmingCharactersInSet:trimSet];
    for (NSString *token in tokens) {
        NSString *normalizedToken = sciNormalizedText(token);
        if ([trimmed isEqualToString:normalizedToken]) return YES;
    }
    return NO;
}

static UIView *sciActionableAncestor(UIView *view) {
    UIView *current = view;
    for (NSInteger depth = 0; current && depth < 7; depth++, current = current.superview) {
        if ([current isKindOfClass:[UIControl class]] ||
            [current isKindOfClass:[UICollectionViewCell class]] ||
            [current isKindOfClass:[UITableViewCell class]] ||
            current.isAccessibilityElement) {
            return current;
        }
    }
    return view;
}

static BOOL sciActivateView(UIView *view) {
    UIView *actionView = sciActionableAncestor(view);
    if (!actionView || !sciViewIsVisible(actionView)) return NO;

    if ([actionView isKindOfClass:[UICollectionViewCell class]]) {
        UICollectionViewCell *cell = (UICollectionViewCell *)actionView;
        UIView *ancestor = cell.superview;
        while (ancestor && ![ancestor isKindOfClass:[UICollectionView class]]) ancestor = ancestor.superview;
        UICollectionView *collectionView = (UICollectionView *)ancestor;
        NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
        if (collectionView && indexPath) {
            [collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            id<UICollectionViewDelegate> delegate = collectionView.delegate;
            if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
                [delegate collectionView:collectionView didSelectItemAtIndexPath:indexPath];
                return YES;
            }
        }
    }

    if ([actionView isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell *)actionView;
        UIView *ancestor = cell.superview;
        while (ancestor && ![ancestor isKindOfClass:[UITableView class]]) ancestor = ancestor.superview;
        UITableView *tableView = (UITableView *)ancestor;
        NSIndexPath *indexPath = [tableView indexPathForCell:cell];
        if (tableView && indexPath) {
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            id<UITableViewDelegate> delegate = tableView.delegate;
            if ([delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                [delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
                return YES;
            }
        }
    }

    if ([actionView isKindOfClass:[UIControl class]]) {
        [(UIControl *)actionView sendActionsForControlEvents:UIControlEventTouchUpInside];
        return YES;
    }

    @try {
        if ([actionView accessibilityActivate]) return YES;
    } @catch (__unused NSException *exception) {}
    return NO;
}

static NSString *sciAccessibilityTextForObject(id object) {
    if (!object) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if ([object isKindOfClass:[UIView class]]) {
        NSString *viewText = sciTextForView((UIView *)object);
        if (viewText.length) [parts addObject:viewText];
    }

    for (NSString *selectorName in @[@"accessibilityLabel", @"accessibilityIdentifier", @"accessibilityValue", @"accessibilityHint"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![object respondsToSelector:selector]) continue;
        @try {
            id value = ((id(*)(id, SEL))objc_msgSend)(object, selector);
            if ([value isKindOfClass:[NSString class]] && [value length]) [parts addObject:value];
        } @catch (__unused NSException *exception) {}
    }
    return sciNormalizedText([parts componentsJoinedByString:@" "]);
}

static CGRect sciScreenFrameForAccessibilityObject(id object) {
    if ([object isKindOfClass:[UIView class]]) {
        UIView *view = (UIView *)object;
        @try {
            return [view convertRect:view.bounds toView:nil];
        } @catch (__unused NSException *exception) {
            return CGRectNull;
        }
    }

    SEL frameSelector = NSSelectorFromString(@"accessibilityFrame");
    if ([object respondsToSelector:frameSelector]) {
        @try {
            return ((CGRect(*)(id, SEL))objc_msgSend)(object, frameSelector);
        } @catch (__unused NSException *exception) {}
    }
    return CGRectNull;
}

static UIAccessibilityTraits sciAccessibilityTraitsForObject(id object) {
    SEL selector = NSSelectorFromString(@"accessibilityTraits");
    if (![object respondsToSelector:selector]) return UIAccessibilityTraitNone;
    @try {
        return ((UIAccessibilityTraits(*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return UIAccessibilityTraitNone;
    }
}

static BOOL sciActivateActionObject(id object) {
    if (!object) return NO;
    if ([object isKindOfClass:[UIView class]]) return sciActivateView((UIView *)object);

    SEL selector = NSSelectorFromString(@"accessibilityActivate");
    if ([object respondsToSelector:selector]) {
        @try {
            return ((BOOL(*)(id, SEL))objc_msgSend)(object, selector);
        } @catch (__unused NSException *exception) {}
    }
    return NO;
}

static void sciCollectAccessibilityObjects(id container,
                                           NSMutableArray *result,
                                           NSMutableSet<NSValue *> *seen,
                                           NSInteger depth) {
    if (!container || depth < 0 || result.count > 1200) return;
    NSValue *identity = [NSValue valueWithPointer:(__bridge const void *)(container)];
    if ([seen containsObject:identity]) return;
    [seen addObject:identity];

    if (![container isKindOfClass:[NSArray class]]) [result addObject:container];

    if ([container isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)container) {
            sciCollectAccessibilityObjects(child, result, seen, depth - 1);
        }
        return;
    }

    SEL elementsSelector = NSSelectorFromString(@"accessibilityElements");
    if ([container respondsToSelector:elementsSelector]) {
        @try {
            id elements = ((id(*)(id, SEL))objc_msgSend)(container, elementsSelector);
            if ([elements isKindOfClass:[NSArray class]]) {
                for (id child in (NSArray *)elements) {
                    sciCollectAccessibilityObjects(child, result, seen, depth - 1);
                }
            }
        } @catch (__unused NSException *exception) {}
    }

    SEL countSelector = NSSelectorFromString(@"accessibilityElementCount");
    SEL itemSelector = NSSelectorFromString(@"accessibilityElementAtIndex:");
    if ([container respondsToSelector:countSelector] && [container respondsToSelector:itemSelector]) {
        @try {
            NSInteger count = ((NSInteger(*)(id, SEL))objc_msgSend)(container, countSelector);
            count = MAX(0, MIN(count, 300));
            for (NSInteger index = 0; index < count; index++) {
                id child = ((id(*)(id, SEL, NSInteger))objc_msgSend)(container, itemSelector, index);
                sciCollectAccessibilityObjects(child, result, seen, depth - 1);
            }
        } @catch (__unused NSException *exception) {}
    }
}

static UIView *sciFloatingBarHostForView(UIView *view) {
    UIView *current = view;
    for (NSInteger depth = 0; current && depth < 24; depth++, current = current.superview) {
        NSString *className = sciNormalizedText(NSStringFromClass(current.class));
        if (sciTextContainsAny(className, @[@"floatingbarhostingview", @"floatingbarcontainer"])) return current;
    }
    return nil;
}

static id sciInstagram434FloatingCreateAction(void) {
    NSArray<UIView *> *visibleViews = sciVisibleViews();
    NSMutableArray<UIView *> *hosts = [NSMutableArray array];
    NSMutableSet<NSValue *> *hostIdentities = [NSMutableSet set];

    for (UIView *view in visibleViews) {
        UIView *host = sciFloatingBarHostForView(view);
        if (!host) continue;
        NSValue *identity = [NSValue valueWithPointer:(__bridge const void *)(host)];
        if (![hostIdentities containsObject:identity]) {
            [hostIdentities addObject:identity];
            [hosts addObject:host];
        }
    }
    if (hosts.count == 0) return nil;

    NSMutableArray *objects = [NSMutableArray array];
    NSMutableSet<NSValue *> *seen = [NSMutableSet set];
    for (UIView *host in hosts) {
        sciCollectAccessibilityObjects(host, objects, seen, 5);
        for (UIView *view in visibleViews) {
            if (sciFloatingBarHostForView(view) == host) {
                sciCollectAccessibilityObjects(view, objects, seen, 2);
            }
        }
    }

    CGRect screenBounds = UIScreen.mainScreen.bounds;
    CGFloat screenWidth = MAX(CGRectGetWidth(screenBounds), 1.0);
    CGFloat screenHeight = MAX(CGRectGetHeight(screenBounds), 1.0);
    NSArray<NSString *> *positiveTokens = @[@"+", @"plus", @"add", @"create", @"create new", @"new post", @"new reel", @"new", @"olustur", @"oluştur", @"yeni gonderi", @"yeni gönderi"];
    NSArray<NSString *> *negativeTokens = @[@"instagram", @"home", @"feed", @"profile", @"search", @"inbox", @"direct", @"message", @"camera", @"notification", @"activity", @"back", @"settings"];

    id bestObject = nil;
    NSInteger bestScore = NSIntegerMin;
    for (id object in objects) {
        NSString *text = sciAccessibilityTextForObject(object);
        NSString *className = sciNormalizedText(NSStringFromClass([object class]));
        BOOL exact = sciTextExactlyMatchesAny(text, positiveTokens);
        BOOL contains = sciTextContainsAny(text, positiveTokens);
        BOOL negative = sciTextContainsAny(text, negativeTokens);
        CGRect frame = sciScreenFrameForAccessibilityObject(object);
        BOOL validFrame = !CGRectIsNull(frame) && !CGRectIsInfinite(frame) && !CGRectIsEmpty(frame);
        CGFloat width = validFrame ? CGRectGetWidth(frame) : 0.0;
        CGFloat height = validFrame ? CGRectGetHeight(frame) : 0.0;
        CGFloat midX = validFrame ? CGRectGetMidX(frame) : CGFLOAT_MAX;
        CGFloat midY = validFrame ? CGRectGetMidY(frame) : CGFLOAT_MAX;
        BOOL compact = validFrame && width >= 18.0 && height >= 18.0 && width <= 140.0 && height <= 140.0;
        BOOL upperLeft = validFrame && midX <= screenWidth * 0.38 && midY <= MAX(210.0, screenHeight * 0.24);
        UIAccessibilityTraits traits = sciAccessibilityTraitsForObject(object);
        BOOL buttonTrait = (traits & UIAccessibilityTraitButton) != 0;
        BOOL actionable = [object isKindOfClass:[UIControl class]] ||
                          [object respondsToSelector:NSSelectorFromString(@"accessibilityActivate")];

        NSInteger score = 0;
        if (exact) score += 420;
        else if (contains) score += 290;
        if (negative) score -= 360;
        if (upperLeft) score += 150;
        if (compact) score += 75;
        if (buttonTrait) score += 90;
        if (actionable) score += 35;
        if ([object isKindOfClass:[UIButton class]]) score += 70;
        else if ([object isKindOfClass:[UIControl class]]) score += 45;
        if (sciTextContainsAny(className, @[@"button", @"control", @"accessibilityelement"])) score += 35;
        if (sciTextContainsAny(className, @[@"floatingbar", @"hostingview"])) score += 30;
        if (validFrame && (width > screenWidth * 0.65 || height > screenHeight * 0.45)) score -= 260;

        BOOL acceptable = contains || exact;
        if (!acceptable) acceptable = upperLeft && compact && buttonTrait && actionable && text.length == 0;
        if (!acceptable) continue;

        if (score > bestScore) {
            bestScore = score;
            bestObject = object;
        }
    }

    if (bestObject) {
        CGRect frame = sciScreenFrameForAccessibilityObject(bestObject);
        NSLog(@"[RyukGram][Repost] Instagram 434 floating create candidate %@ text='%@' frame=%@ score=%ld",
              NSStringFromClass([bestObject class]),
              sciAccessibilityTextForObject(bestObject),
              NSStringFromCGRect(frame),
              (long)bestScore);
    }
    return bestScore >= 220 ? bestObject : nil;
}

static UIView *sciBestActionForTokens(NSArray<NSString *> *tokens,
                                      NSArray<NSString *> *classHints,
                                      BOOL preferExact) {
    UIView *bestView = nil;
    NSInteger bestScore = NSIntegerMin;
    for (UIView *view in sciVisibleViews()) {
        NSString *text = sciTextForView(view);
        BOOL exact = sciTextExactlyMatchesAny(text, tokens);
        BOOL contains = sciTextContainsAny(text, tokens);
        if (!exact && !contains) continue;

        NSString *className = sciNormalizedText(NSStringFromClass(view.class));
        NSInteger score = exact ? 140 : 70;
        if (preferExact && !exact) score -= 35;
        if ([view isKindOfClass:[UIButton class]]) score += 50;
        else if ([view isKindOfClass:[UIControl class]]) score += 35;
        else if ([view isKindOfClass:[UICollectionViewCell class]] || [view isKindOfClass:[UITableViewCell class]]) score += 25;
        if (view.isAccessibilityElement) score += 15;
        if (sciTextContainsAny(className, classHints)) score += 45;
        if (CGRectGetHeight(view.bounds) < 20.0 || CGRectGetWidth(view.bounds) < 20.0) score -= 30;

        if (score > bestScore) {
            bestScore = score;
            bestView = view;
        }
    }
    return bestView;
}
