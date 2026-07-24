
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
