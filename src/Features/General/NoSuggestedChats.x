#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Channels DMs tab (header)
%hook IGDirectInboxHeaderSectionController
- (id)viewModel {
    id viewModel = %orig;
    NSString *title = nil;
    if ([viewModel respondsToSelector:@selector(title)]) {
        @try { title = [viewModel title]; }
        @catch (__unused NSException *exception) {}
    }

    if ([title isEqualToString:@"Suggested"] &&
        [SCIUtils getBoolPref:@"no_suggested_chats"]) {
        NSLog(@"[SCInsta] Hiding suggested chats (header: channels tab)");
        return nil;
    }

    return viewModel;
}
%end
