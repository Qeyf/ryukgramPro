static BOOL sciObjectContainsLocalIdentifier(id object, NSString *identifier, NSInteger depth) {
    if (!object || identifier.length == 0 || depth < 0) return NO;
    if ([object isKindOfClass:[NSString class]]) {
        NSString *value = (NSString *)object;
        return [value isEqualToString:identifier] || [value containsString:identifier];
    }
    if ([object isKindOfClass:[PHAsset class]]) {
        return [((PHAsset *)object).localIdentifier isEqualToString:identifier];
    }
    if ([object isKindOfClass:[NSArray class]]) {
        for (id child in (NSArray *)object) {
            if (sciObjectContainsLocalIdentifier(child, identifier, depth - 1)) return YES;
        }
        return NO;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        for (id child in ((NSDictionary *)object).allValues) {
            if (sciObjectContainsLocalIdentifier(child, identifier, depth - 1)) return YES;
        }
        return NO;
    }

    for (NSString *selectorName in @[@"localIdentifier", @"asset", @"photoAsset", @"mediaAsset", @"phAsset", @"model", @"viewModel", @"item"]) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![object respondsToSelector:selector]) continue;
        @try {
            id value = ((id(*)(id, SEL))objc_msgSend)(object, selector);
            if (value != object && sciObjectContainsLocalIdentifier(value, identifier, depth - 1)) return YES;
        } @catch (__unused NSException *exception) {}
    }

    if (depth == 0) return NO;
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([object class], &count);
    for (unsigned int index = 0; index < count; index++) {
        const char *type = ivar_getTypeEncoding(ivars[index]);
        if (!type || type[0] != '@') continue;
        @try {
            id value = object_getIvar(object, ivars[index]);
            if (value != object && sciObjectContainsLocalIdentifier(value, identifier, depth - 1)) {
                free(ivars);
                return YES;
            }
        } @catch (__unused NSException *exception) {}
    }
    if (ivars) free(ivars);
    return NO;
}

static UICollectionViewCell *sciCellMatchingAsset(NSString *localIdentifier) {
    for (UIView *view in sciVisibleViews()) {
        if (![view isKindOfClass:[UICollectionViewCell class]]) continue;
        if (sciObjectContainsLocalIdentifier(view, localIdentifier, 2)) {
            return (UICollectionViewCell *)view;
        }
    }
    return nil;
}

static UICollectionViewCell *sciFirstLikelyMediaCell(void) {
    UICollectionViewCell *bestCell = nil;
    NSInteger bestScore = NSIntegerMin;
    for (UIView *view in sciVisibleViews()) {
        if (![view isKindOfClass:[UICollectionViewCell class]]) continue;
        UICollectionViewCell *cell = (UICollectionViewCell *)view;
        UIView *ancestor = cell.superview;
        while (ancestor && ![ancestor isKindOfClass:[UICollectionView class]]) ancestor = ancestor.superview;
        UICollectionView *collectionView = (UICollectionView *)ancestor;
        NSIndexPath *indexPath = [collectionView indexPathForCell:cell];
        if (!collectionView || !indexPath) continue;

        NSString *context = [NSString stringWithFormat:@"%@ %@ %@",
                             NSStringFromClass(cell.class),
                             NSStringFromClass(collectionView.class),
                             sciTextForView(collectionView)];
        NSString *normalized = sciNormalizedText(context);
        NSInteger score = 0;
        if (sciTextContainsAny(normalized, @[@"gallery", @"picker", @"camera", @"photo", @"media", @"creation"])) score += 100;
        if (indexPath.section == 0) score += 20;
        score += MAX(0, 30 - (NSInteger)indexPath.item);
        if (CGRectGetWidth(cell.bounds) > 60.0 && CGRectGetHeight(cell.bounds) > 60.0) score += 15;
        if (score > bestScore) {
            bestScore = score;
            bestCell = cell;
        }
    }
    return bestScore >= 20 ? bestCell : nil;
}

static UIView *sciCaptionInput(void) {
    UIView *best = nil;
    NSInteger bestScore = NSIntegerMin;
    for (UIView *view in sciVisibleViews()) {
        if (![view isKindOfClass:[UITextView class]] && ![view isKindOfClass:[UITextField class]]) continue;
        NSString *text = sciTextForView(view);
        NSString *className = sciNormalizedText(NSStringFromClass(view.class));
        NSInteger score = 0;
        if (sciTextContainsAny(text, @[@"caption", @"write a caption", @"aciklama", @"açıklama", @"baslik", @"başlık"])) score += 180;
        if (sciTextContainsAny(className, @[@"caption", @"creation", @"composer"])) score += 100;
        if (sciTextContainsAny(text, @[@"search", @"ara", @"comment", @"yorum", @"message", @"mesaj"])) score -= 180;
        if ([view isKindOfClass:[UITextView class]] && CGRectGetHeight(view.bounds) > 44.0) score += 35;
        if (score > bestScore) {
            bestScore = score;
            best = view;
        }
    }
    return bestScore >= 30 ? best : nil;
}

static BOOL sciSetCaptionOnInput(UIView *input, NSString *caption) {
    if (!input || caption.length == 0) return YES;
    @try {
        if ([input isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)input;
            [textView becomeFirstResponder];
            textView.text = caption;
            [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];
            id<UITextViewDelegate> delegate = textView.delegate;
            if ([delegate respondsToSelector:@selector(textViewDidChange:)]) [delegate textViewDidChange:textView];
            [textView resignFirstResponder];
            return YES;
        }
        if ([input isKindOfClass:[UITextField class]]) {
            UITextField *field = (UITextField *)input;
            [field becomeFirstResponder];
            field.text = caption;
            [field sendActionsForControlEvents:UIControlEventEditingChanged];
            [field sendActionsForControlEvents:UIControlEventEditingDidEnd];
            [field resignFirstResponder];
            return YES;
        }
    } @catch (__unused NSException *exception) {}
    return NO;
}

static NSArray<UIViewController *> *sciControllerCandidates(void) {
    NSMutableArray<UIViewController *> *result = [NSMutableArray array];
    for (UIWindow *window in sciForegroundWindows()) {
        UIViewController *root = window.rootViewController;
        if (!root) continue;
