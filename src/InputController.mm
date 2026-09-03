#import <AppKit/NSSpellChecker.h>
#import <CoreServices/CoreServices.h>

#import "InputApplicationDelegate.h"
#import "InputController.h"

extern IMKCandidates *sharedCandidates;
extern NSUserDefaults *preference;
extern ConversionEngine *engine;

#define MAX_RECENT_WORDS 4

typedef NSInteger KeyCode;
static const KeyCode KEY_RETURN = 36, KEY_SPACE = 49, KEY_DELETE = 51, KEY_ESC = 53, KEY_ARROW_DOWN = 125, KEY_ARROW_UP = 126;

@interface InputController ()

- (void)showIMEPreferences:(id)sender;
- (void)clickAbout:(NSMenuItem *)sender;
- (void)commitFrenchPunctuation:(NSString *)punctuation client:(id)sender;
- (BOOL)isFrenchApostrophe:(NSString *)characters;

@end

@implementation InputController

- (NSUInteger)recognizedEvents:(id)sender {
    return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    NSUInteger modifiers = event.modifierFlags;
    bool handled = NO;
    switch (event.type) {
    case NSEventTypeFlagsChanged:
        if (_lastEventType == NSEventTypeFlagsChanged && _lastModifiers == modifiers) {
            return YES;
        }
        break;
    case NSEventTypeKeyDown:
        // ignore Command+X hotkeys.
        if (modifiers & NSEventModifierFlagCommand)
            break;

        if (modifiers & NSEventModifierFlagOption) {
            return false;
        }

        if (modifiers & NSEventModifierFlagControl) {
            return false;
        }

        handled = [self onKeyEvent:event client:sender];
        break;
    default:
        break;
    }

    _lastModifiers = modifiers;
    _lastEventType = event.type;
    return handled;
}

- (BOOL)onKeyEvent:(NSEvent *)event client:(id)sender {
    _currentClient = sender;
    NSInteger keyCode = event.keyCode;
    NSString *characters = event.characters;

    NSString *bufferedText = [self originalBuffer];
    bool hasBufferedText = bufferedText && bufferedText.length > 0;

    if (keyCode == KEY_DELETE) {
        if (hasBufferedText) {
            return [self deleteBackward:sender];
        }

        return NO;
    }

    if (keyCode == KEY_SPACE) {
        if (hasBufferedText) {
            [self commitComposition:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_RETURN) {
        if (hasBufferedText) {
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_ESC) {
        [self cancelComposition];
        [sender insertText:@""];
        [self reset];
        [self resetContext];
        return YES;
    }

    if (characters.length == 0)
        return NO;

    unichar ch = [characters characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        [self originalBufferAppend:characters client:sender];

        [sharedCandidates updateCandidates];
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        return YES;
    }

    BOOL isCandidatesVisible = [sharedCandidates isVisible];
    if (isCandidatesVisible) {
        if (keyCode == KEY_ARROW_DOWN) {
            [sharedCandidates moveDown:self];
            _currentCandidateIndex = MIN(_currentCandidateIndex + 1, (NSInteger)_candidates.count);
            return YES;
        }

        if (keyCode == KEY_ARROW_UP) {
            [sharedCandidates moveUp:self];
            _currentCandidateIndex = MAX(_currentCandidateIndex - 1, 1);
            return YES;
        }
    }

    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
        if (!hasBufferedText) {
            [self appendToComposedBuffer:characters];
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }

        if (isCandidatesVisible) { // use 1~9 digital numbers as selection keys
            NSInteger pressedNumber = characters.integerValue;
            NSInteger pageSize = 9;
            if (pressedNumber < 1 || pressedNumber > pageSize)
                return YES;

            NSInteger selectedCandidateIndex = MAX(_currentCandidateIndex - 1, 0);
            NSInteger pageStartIndex = (selectedCandidateIndex / pageSize) * pageSize;
            NSInteger candidateIndex = pageStartIndex + pressedNumber - 1;
            if (candidateIndex >= (NSInteger)_candidates.count)
                return YES;

            NSString *candidate = _candidates[candidateIndex];
            [self cancelComposition];
            [self setComposedBuffer:candidate];
            [self setOriginalBuffer:candidate];
            [self commitComposition:sender];
            return YES;
        }
    }

    if (hasBufferedText && [self isFrenchApostrophe:characters]) {
        [self setComposedBuffer:bufferedText];
        [self appendToComposedBuffer:@"’"];
        [self commitCompositionWithoutSpace:sender];
        return YES;
    }

    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch] || [[NSCharacterSet symbolCharacterSet] characterIsMember:ch]) {
        if (hasBufferedText) {
            [self commitFrenchPunctuation:characters client:sender];
            return YES;
        }
    }

    return NO;
}

- (BOOL)isFrenchApostrophe:(NSString *)characters {
    return [characters isEqualToString:@"'"] || [characters isEqualToString:@"‘"] || [characters isEqualToString:@"’"];
}

- (void)commitFrenchPunctuation:(NSString *)punctuation client:(id)sender {
    NSString *text = [self composedBuffer];
    if (text.length == 0)
        text = [self originalBuffer];
    [self recordCommittedWord:text];

    NSSet *spacedPunctuation = [NSSet setWithArray:@[ @";", @":", @"!", @"?" ]];
    NSSet *sentenceEndings = [NSSet setWithArray:@[ @".", @"!", @"?" ]];
    if ([spacedPunctuation containsObject:punctuation]) {
        text = [NSString stringWithFormat:@"%@\u202F%@ ", text, punctuation];
    } else if ([punctuation isEqualToString:@","] || [punctuation isEqualToString:@"."]) {
        text = [NSString stringWithFormat:@"%@%@ ", text, punctuation];
    } else {
        text = [text stringByAppendingString:punctuation];
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self reset];
    if ([sentenceEndings containsObject:punctuation])
        [self resetContext];
}

- (BOOL)deleteBackward:(id)sender {
    NSMutableString *originalText = [self originalBuffer];

    if (originalText.length > 0) {
        NSString *convertedString = [originalText substringToIndex:originalText.length - 1];
        _insertionIndex = convertedString.length;

        [self setComposedBuffer:convertedString];
        [self setOriginalBuffer:convertedString];

        [self showPreeditString:convertedString];

        if (convertedString && convertedString.length > 0) {
            [sharedCandidates updateCandidates];
            [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        } else {
            [self reset];
        }
        return YES;
    }
    return NO;
}

- (void)commitComposition:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [self recordCommittedWord:text];

    BOOL commitWordWithSpace = [preference boolForKey:@"commitWordWithSpace"];

    if (commitWordWithSpace && text.length > 0) {
        unichar firstChar = [text characterAtIndex:0];
        unichar lastChar = [text characterAtIndex:text.length - 1];
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:firstChar] && lastChar != '\'' && lastChar != 0x2019) {
            text = [NSString stringWithFormat:@"%@ ", text];
        }
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)commitCompositionWithoutSpace:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [self recordCommittedWord:text];

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)reset {
    [self setComposedBuffer:@""];
    [self setOriginalBuffer:@""];
    _insertionIndex = 0;
    _currentCandidateIndex = 1;
    [sharedCandidates clearSelection];
    [sharedCandidates hide];
    _candidates = [[NSMutableArray alloc] init];
    [sharedCandidates setCandidateData:@[]];
}

- (void)resetContext {
    [_recentWords removeAllObjects];
}

- (NSString *)recentContext {
    if (_recentWords.count == 0)
        return nil;
    return [_recentWords componentsJoinedByString:@" "];
}

- (void)recordCommittedWord:(NSString *)word {
    if (!word || word.length == 0)
        return;
    if (!_recentWords)
        _recentWords = [[NSMutableArray alloc] init];
    NSString *trimmed = [word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *normalized = [[trimmed lowercaseString] stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
    NSSet *elidedPrefixes = [NSSet setWithArray:@[ @"c'", @"d'", @"j'", @"l'", @"m'", @"n'", @"qu'", @"s'", @"t'" ]];
    if ([elidedPrefixes containsObject:normalized]) {
        [_recentWords addObject:normalized];
        while (_recentWords.count > MAX_RECENT_WORDS)
            [_recentWords removeObjectAtIndex:0];
        return;
    }

    trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
    if (trimmed.length == 0)
        return;

    // French elisions such as j’aime and qu’il are one lexical context item.
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    for (NSInteger i = 0; i < (NSInteger)trimmed.length; i++) {
        unichar character = [trimmed characterAtIndex:i];
        if (![letters characterIsMember:character] && character != '\'' && character != 0x2019)
            return;
    }

    normalized = [[trimmed lowercaseString] stringByReplacingOccurrencesOfString:@"’" withString:@"'"];
    if ([_recentWords.lastObject hasSuffix:@"'"])
        _recentWords[_recentWords.count - 1] = [_recentWords.lastObject stringByAppendingString:normalized];
    else
        [_recentWords addObject:normalized];
    while (_recentWords.count > MAX_RECENT_WORDS) {
        [_recentWords removeObjectAtIndex:0];
    }
}

- (NSMutableString *)composedBuffer {
    if (_composedBuffer == nil) {
        _composedBuffer = [[NSMutableString alloc] init];
    }
    return _composedBuffer;
}

- (void)setComposedBuffer:(NSString *)string {
    NSMutableString *buffer = [self composedBuffer];
    [buffer setString:string];
}

- (NSMutableString *)originalBuffer {
    if (_originalBuffer == nil) {
        _originalBuffer = [[NSMutableString alloc] init];
    }
    return _originalBuffer;
}

- (void)setOriginalBuffer:(NSString *)input {
    NSMutableString *buffer = [self originalBuffer];
    [buffer setString:input];
}

- (void)showPreeditString:(NSString *)input {
    NSDictionary *attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:NSMakeRange(0, input.length)];
    NSAttributedString *attrString;

    NSString *originalBuff = [NSString stringWithString:[self originalBuffer]];
    if ([input.lowercaseString hasPrefix:originalBuff.lowercaseString]) {
        attrString = [[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%@%@", originalBuff, [input substringFromIndex:originalBuff.length]]
                attributes:attrs];
    } else {
        attrString = [[NSAttributedString alloc] initWithString:input attributes:attrs];
    }

    [_currentClient setMarkedText:attrString
                   selectionRange:NSMakeRange(input.length, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)originalBufferAppend:(NSString *)input client:(id)sender {
    NSMutableString *buffer = [self originalBuffer];
    [buffer appendString:input];
    _insertionIndex++;
    [self showPreeditString:buffer];
}

- (void)appendToComposedBuffer:(NSString *)input {
    NSMutableString *buffer = [self composedBuffer];
    [buffer appendString:input];
}

- (NSArray *)candidates:(id)sender {
    NSString *originalInput = [self originalBuffer];

    NSArray *candidateList = [engine getFrenchCandidates:originalInput];

    // A single typed letter matches far too many conjugated forms to usefully narrow
    // anything down (e.g. "p" after "je" would jump straight to "parle"), so frequency-
    // ranked dictionary words stay in charge until there's at least a two-letter prefix.
    NSString *ctx = [self recentContext];
    if (ctx && originalInput.length > 1) {
        NSArray *conjugations = [engine getFrenchConjugations:originalInput context:ctx maxResults:8];
        NSArray *predictions = [engine predictFrenchWordsForContext:ctx prefixFilter:originalInput maxResults:5];
        if (conjugations.count > 0 || predictions.count > 0) {
            NSString *firstCandidate = candidateList.firstObject;
            BOOL firstCandidateIsExact = firstCandidate.length > 0 &&
                [[engine normalizeFrenchText:firstCandidate] isEqualToString:[engine normalizeFrenchText:originalInput]];
            NSArray *exactMatch = firstCandidateIsExact ? @[ firstCandidate ] : @[];
            NSArray *remainingCandidates = firstCandidateIsExact && candidateList.count > 1
                ? [candidateList subarrayWithRange:NSMakeRange(1, candidateList.count - 1)]
                : candidateList;
            NSArray *rankedGroups = firstCandidateIsExact
                ? @[ exactMatch, predictions, remainingCandidates, conjugations ]
                : @[ conjugations, predictions, remainingCandidates ];
            NSArray *result = [engine mergeFrenchCandidateGroups:rankedGroups
                                                          maxResults:50];
            _candidates = [NSMutableArray arrayWithArray:result];
            _currentCandidateIndex = 1;
            return result;
        }
    }

    _candidates = [NSMutableArray arrayWithArray:candidateList];
    _currentCandidateIndex = 1;
    return candidateList;
}

- (void)candidateSelectionChanged:(NSAttributedString *)candidateString {
    [self _updateComposedBuffer:candidateString];

    NSUInteger selectedIndex = [_candidates indexOfObject:candidateString.string];
    if (selectedIndex != NSNotFound)
        _currentCandidateIndex = (NSInteger)selectedIndex + 1;

    [self showPreeditString:candidateString.string];

    _insertionIndex = [self originalBuffer].length;
}

- (void)candidateSelected:(NSAttributedString *)candidateString {
    [self _updateComposedBuffer:candidateString];

    [self commitComposition:_currentClient];
}

- (void)_updateComposedBuffer:(NSAttributedString *)candidateString {
    [self setComposedBuffer:candidateString.string];
}

- (void)activateServer:(id)sender {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];

    _currentCandidateIndex = 1;
    _candidates = [[NSMutableArray alloc] init];
    _recentWords = [[NSMutableArray alloc] init];
}

- (void)deactivateServer:(id)sender {
    [self reset];
    [self resetContext];
}

- (NSMenu *)menu {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [NSApp.delegate performSelector:NSSelectorFromString(@"menu")];
#pragma clang diagnostic pop
}

- (void)showIMEPreferences:(id)sender {
    [self openUrl:@"http://localhost:62718/index.html"];
}

- (void)clickAbout:(NSMenuItem *)sender {
    [self openUrl:@"https://github.com/jinyanshao/Plume-Francaise"];
}

- (void)openUrl:(NSString *)url {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];

    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration new];
    configuration.promptsUserIfNeeded = YES;
    configuration.createsNewApplicationInstance = NO;

    [ws openURL:[NSURL URLWithString:url]
            configuration:configuration
        completionHandler:^(NSRunningApplication *_Nullable app, NSError *_Nullable error) {
            if (error) {
                NSLog(@"Failed to run the app: %@", error.localizedDescription);
            }
        }];
}

@end
