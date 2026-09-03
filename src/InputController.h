#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#import "ConversionEngine.h"

@interface InputController : IMKInputController {
    NSMutableString *_composedBuffer;
    NSMutableString *_originalBuffer;
    NSInteger _insertionIndex;
    NSInteger _currentCandidateIndex;
    NSMutableArray *_candidates;
    id _currentClient;
    NSUInteger _lastModifiers;
    NSEventType _lastEventType;
    NSMutableArray<NSString *> *_recentWords;
}

- (NSMutableString *)composedBuffer;
- (void)setComposedBuffer:(NSString *)string;
- (NSMutableString *)originalBuffer;
- (void)originalBufferAppend:(NSString *)string client:(id)sender;
- (void)setOriginalBuffer:(NSString *)string;
- (NSString *)recentContext;
- (void)recordCommittedWord:(NSString *)word;
- (void)resetContext;

@end
