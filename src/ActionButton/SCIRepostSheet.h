// SCIRepostSheet — prepares credited media and opens Instagram's native creator.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIRepostSheet : NSObject

/// Present the native Reel / Feed Post destination picker for an IGMedia object.
+ (void)presentForMedia:(nullable id)media fromView:(nullable UIView *)sourceView;

/// Compatibility entry point for existing callers that only have media URLs.
+ (void)repostWithVideoURL:(nullable NSURL *)videoURL photoURL:(nullable NSURL *)photoURL;

@end

NS_ASSUME_NONNULL_END
