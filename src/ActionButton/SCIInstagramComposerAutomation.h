#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIInstagramComposerAutomation : NSObject

+ (void)startWithLocalIdentifier:(NSString *)localIdentifier
                          asReel:(BOOL)asReel
                         caption:(nullable NSString *)caption
                      completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

+ (BOOL)isRunning;
+ (void)cancel;

@end

NS_ASSUME_NONNULL_END
