#import "../../Utils.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *kSCILegacyVoiceMessageConfirmBypassKey = &kSCILegacyVoiceMessageConfirmBypassKey;
static const void *kSCIAIVoiceMessageConfirmBypassKey = &kSCIAIVoiceMessageConfirmBypassKey;

static BOOL sciConsumeVoiceMessageConfirmBypass(id target, const void *key) {
    if (![objc_getAssociatedObject(target, key) boolValue]) return NO;
    objc_setAssociatedObject(target, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void sciReplayLegacyVoiceMessage(id target,
                                        id controller,
                                        id URL,
                                        id waveform,
                                        CGFloat duration,
                                        NSInteger entryPoint) {
    if (!target) return;
    objc_setAssociatedObject(target,
                             kSCILegacyVoiceMessageConfirmBypassKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id, id, id, CGFloat, NSInteger))objc_msgSend)(
        target,
        @selector(voiceRecordViewController:didRecordAudioClipWithURL:waveform:duration:entryPoint:),
        controller,
        URL,
        waveform,
        duration,
        entryPoint
    );
}

static void sciReplayAIVoiceMessage(id target) {
    if (!target) return;
    objc_setAssociatedObject(target,
                             kSCIAIVoiceMessageConfirmBypassKey,
                             @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(target, @selector(didTapSend));
}

// Legacy hook (for non-AI voices interface)
%hook IGDirectThreadViewController
- (void)voiceRecordViewController:(id)arg1
    didRecordAudioClipWithURL:(id)arg2
                     waveform:(id)arg3
                     duration:(CGFloat)arg4
                   entryPoint:(NSInteger)arg5 {
    if (sciConsumeVoiceMessageConfirmBypass(self, kSCILegacyVoiceMessageConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"voice_message_confirm"]) {
        %orig(arg1, arg2, arg3, arg4, arg5);
        return;
    }

    NSLog(@"[SCInsta] DM audio message confirm triggered");
    __weak id weakSelf = self;
    id capturedController = arg1;
    id capturedURL = arg2;
    id capturedWaveform = arg3;
    CGFloat capturedDuration = arg4;
    NSInteger capturedEntryPoint = arg5;
    [SCIUtils showConfirmation:^{
        sciReplayLegacyVoiceMessage(weakSelf,
                                    capturedController,
                                    capturedURL,
                                    capturedWaveform,
                                    capturedDuration,
                                    capturedEntryPoint);
    }];
}
%end

// Workaround until long-press recording can be stopped from automatically sending.
%hook IGDirectComposer
- (void)_didLongPressVoiceMessage:(id)arg1 {
    if ([SCIUtils getBoolPref:@"voice_message_confirm"]) return;
    %orig(arg1);
}
%end

// Demangled name: IGDirectAIVoiceUIKit.CompactBarContentView
%hook _TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView
- (void)didTapSend {
    if (sciConsumeVoiceMessageConfirmBypass(self, kSCIAIVoiceMessageConfirmBypassKey) ||
        ![SCIUtils getBoolPref:@"voice_message_confirm"]) {
        %orig;
        return;
    }

    NSLog(@"[SCInsta] DM audio message confirm triggered");
    __weak id weakSelf = self;
    [SCIUtils showConfirmation:^{
        sciReplayAIVoiceMessage(weakSelf);
    }];
}
%end
