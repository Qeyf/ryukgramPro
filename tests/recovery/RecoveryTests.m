#import <Foundation/Foundation.h>
#import "SCIDashParser.h"
#import "ActionButton/SCIMediaMetadata.h"

@interface CacheA : NSObject { @public NSDictionary *_fieldCache; }
@end
@implementation CacheA @end
@interface CacheB : NSObject { @public long _padding[12]; NSDictionary *_fieldCache; }
@end
@implementation CacheB @end
@interface CacheChild : CacheB @end
@implementation CacheChild @end

static NSUInteger checks;
static void Check(BOOL value, NSString *message) {
    checks++;
    if (!value) { NSLog(@"FAIL: %@", message); exit(1); }
}
static SCIDashRepresentation *Rep(NSString *type, NSInteger bandwidth) {
    SCIDashRepresentation *rep = [SCIDashRepresentation new];
    rep.contentType = type; rep.bandwidth = bandwidth;
    return rep;
}
int main(void) {
    @autoreleasepool {
        Check([SCICaptionWithSource(@"Balık 🐟", @"balikcepte") isEqual:@"Balık 🐟\n\nkaynak: @balikcepte"], @"Credit and Unicode");
        Check([SCICaptionWithSource(@"Metin\r\n\n", @"@author") isEqual:@"Metin\n\nkaynak: @author"], @"Trailing CR/LF and existing at sign");
        Check([SCICaptionWithSource(@"Metin  ", @"author") isEqual:@"Metin  \n\nkaynak: @author"], @"Preserve trailing spaces");
        Check([SCICaptionWithSource(@"Bir\nİki", nil) isEqual:@"Bir\nİki"], @"Missing author retains raw caption");
        Check([SCICaptionWithSource(@"", @"author") isEqual:@""], @"Empty caption stays empty");
        Check(SCICaptionWithSource(nil, @"author") == nil, @"Nil caption stays nil");

        CacheA *a = [CacheA new]; a->_fieldCache = @{@"text": @"A"};
        CacheB *b = [CacheB new]; b->_fieldCache = @{@"text": @"B", @"missing": NSNull.null};
        CacheChild *child = [CacheChild new]; child->_fieldCache = @{@"text": @"child"};
        Check([SCIFieldCacheValue(a, @"text") isEqual:@"A"], @"First class cache");
        Check([SCIFieldCacheValue(b, @"text") isEqual:@"B"], @"Different class ivar offset");
        Check([SCIFieldCacheValue(child, @"text") isEqual:@"child"], @"Inherited ivar");
        Check([SCIFieldCacheValue(@{@"text": @"dictionary"}, @"text") isEqual:@"dictionary"], @"Dictionary passthrough");
        Check(SCIFieldCacheValue(b, @"missing") == nil, @"NSNull becomes nil");
        Check(SCIFieldCacheValue([NSObject new], @"text") == nil, @"Missing ivar");
        Check(SCIFieldCacheValue(a, @"") == nil, @"Empty key");

        SCIDashRepresentation *low = Rep(@"audio", 64000), *high = Rep(@"audio", 256000);
        SCIDashRepresentation *video = Rep(@"video", 9000000);
        NSArray *input = @[low, video, high];
        NSArray *audio = [SCIDashParser audioRepresentations:input];
        Check([audio isEqual:@[high, low]], @"Audio only, descending bandwidth");
        Check(input.count == 3 && input.firstObject == low, @"Input remains unchanged");
        Check([SCIDashParser bestAudioFromRepresentations:input] == high, @"Highest audio");
        Check([SCIDashParser audioRepresentations:@[]].count == 0, @"Empty audio list");
        Check([SCIDashParser audioRepresentations:@[video]].count == 0, @"Video-only input");
        Check([SCIDashParser bestAudioFromRepresentations:@[]] == nil, @"Empty best audio");
        SCIDashRepresentation *equal = Rep(@"audio", 64000);
        Check([SCIDashParser audioRepresentations:@[low, equal]].count == 2, @"Equal rates retained");
        NSLog(@"PASS: %lu recovery behavior checks", (unsigned long)checks);
    }
    return 0;
}
