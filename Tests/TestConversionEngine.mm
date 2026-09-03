#import "ConversionEngine.h"
#import "InputController.h"
#import <XCTest/XCTest.h>

@interface InputController (Tests)
- (BOOL)onKeyEvent:(NSEvent *)event client:(id)sender;
- (NSArray *)candidates:(id)sender;
- (void)candidateSelectionChanged:(NSAttributedString *)candidateString;
- (void)commitFrenchPunctuation:(NSString *)punctuation client:(id)sender;
@end

@interface FakeInsertClient : NSObject
@property(nonatomic, copy) NSString *insertedText;
@end

@implementation FakeInsertClient
- (void)insertText:(id)aString replacementRange:(NSRange)replacementRange {
    self.insertedText = [aString isKindOfClass:[NSAttributedString class]] ? [(NSAttributedString *)aString string] : aString;
}
@end

@interface TestInputController : InputController
@property(nonatomic, copy) NSString *lastPreeditString;
@property(nonatomic) NSInteger preeditCallCount;
- (NSInteger)insertionIndex;
- (NSInteger)currentCandidateIndex;
- (void)setCurrentCandidateIndex:(NSInteger)index;
- (void)setHasNavigatedCandidates:(BOOL)navigated;
@end

@implementation TestInputController

- (void)showPreeditString:(NSString *)input {
    self.lastPreeditString = input;
    self.preeditCallCount++;
}

- (NSInteger)insertionIndex {
    return _insertionIndex;
}

- (NSInteger)currentCandidateIndex {
    return _currentCandidateIndex;
}

- (void)setCurrentCandidateIndex:(NSInteger)index {
    _currentCandidateIndex = index;
}

- (void)setHasNavigatedCandidates:(BOOL)navigated {
    _hasNavigatedCandidates = navigated;
}

@end

@interface TestConversionEngine : XCTestCase
@property ConversionEngine *engine;
@end

@implementation TestConversionEngine

- (void)setUp {
    self.engine = [ConversionEngine sharedEngine];
}

- (void)testAccentCandidates {
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"ecole"].firstObject, @"école");
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"ca"].firstObject, @"ça");
    XCTAssertTrue([[self.engine getFrenchCandidates:@"etre"] containsObject:@"être"]);
    XCTAssertTrue([[self.engine getFrenchCandidates:@"hotel"] containsObject:@"hôtel"]);
}

- (void)testUppercaseAccentCandidate {
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"Ecole"].firstObject, @"École");
}

- (void)testElisions {
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"lhomme"].firstObject, @"l’homme");
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"jaime"].firstObject, @"j’aime");
    XCTAssertEqualObjects([self.engine getFrenchCandidates:@"quil"].firstObject, @"qu’il");
}

- (void)testContextPrediction {
    NSArray *predictions = [self.engine predictFrenchWordsForContext:@"je suis" prefixFilter:@"h" maxResults:5];
    XCTAssertEqualObjects(predictions.firstObject, @"heureux");

    NSArray *accented = [self.engine predictFrenchWordsForContext:@"je suis" prefixFilter:@"d" maxResults:5];
    XCTAssertEqualObjects(accented.firstObject, @"désolé");
}

- (void)testPredictionLimit {
    NSArray *predictions = [self.engine predictFrenchWordsForContext:@"je suis" prefixFilter:@"" maxResults:3];
    XCTAssertEqual(predictions.count, 3);
}

- (void)testCommonVerbConjugations {
    NSArray *forms = [self.engine getFrenchConjugations:@"aller" maxResults:10];
    XCTAssertTrue([forms containsObject:@"vais"]);
    XCTAssertTrue([forms containsObject:@"vas"]);
    XCTAssertTrue([forms containsObject:@"va"]);
    XCTAssertTrue([forms containsObject:@"allons"]);
}

- (void)testEssentialVerbConjugations {
    XCTAssertTrue([[self.engine getFrenchConjugations:@"etre" context:@"je" maxResults:40] containsObject:@"suis"]);
    XCTAssertTrue([[self.engine getFrenchConjugations:@"pouv" context:@"je" maxResults:40] containsObject:@"peux"]);
    XCTAssertTrue([[self.engine getFrenchConjugations:@"prend" context:@"nous" maxResults:40] containsObject:@"prenons"]);
    XCTAssertTrue([[self.engine getFrenchConjugations:@"mett" context:@"vous" maxResults:40] containsObject:@"mettez"]);

    NSArray *falloirForms = [self.engine getFrenchConjugations:@"falloir" context:@"il" maxResults:10];
    XCTAssertTrue([falloirForms containsObject:@"faut"]);
    XCTAssertTrue([falloirForms containsObject:@"fallait"]);
    XCTAssertTrue([falloirForms containsObject:@"faudra"]);
    XCTAssertTrue([falloirForms containsObject:@"a fallu"]);
}

- (void)testConjugationsIncludeFourTenses {
    NSArray *forms = [self.engine getFrenchConjugations:@"aller" context:@"je" maxResults:30];
    XCTAssertTrue([forms containsObject:@"vais"]);
    XCTAssertTrue([forms containsObject:@"allais"]);
    XCTAssertTrue([forms containsObject:@"irai"]);
    XCTAssertTrue([forms containsObject:@"suis allé"]);
}

- (void)testCompoundPastSupportsDualAuxiliaries {
    NSArray *sortirForms = [self.engine getFrenchConjugations:@"sortir" context:@"je" maxResults:40];
    XCTAssertTrue([sortirForms containsObject:@"suis sorti"]);
    XCTAssertTrue([sortirForms containsObject:@"ai sorti"]);

    NSArray *monterForms = [self.engine getFrenchConjugations:@"monter" context:@"elle" maxResults:40];
    XCTAssertTrue([monterForms containsObject:@"est montée"]);
    XCTAssertTrue([monterForms containsObject:@"a monté"]);

    NSArray *passerForms = [self.engine getFrenchConjugations:@"passer" context:@"nous" maxResults:40];
    XCTAssertTrue([passerForms containsObject:@"sommes passés"]);
    XCTAssertTrue([passerForms containsObject:@"avons passé"]);

    NSArray *venirForms = [self.engine getFrenchConjugations:@"venir" context:@"je" maxResults:40];
    XCTAssertTrue([venirForms containsObject:@"suis venu"]);
    XCTAssertFalse([venirForms containsObject:@"ai venu"]);
}

- (void)testDirectObjectContextRanksAvoirFirst {
    NSDictionary *dualAuxiliaryForms = @{
        @"descendre" : @[ @"ai descendu", @"suis descendu" ],
        @"monter" : @[ @"ai monté", @"suis monté" ],
        @"passer" : @[ @"ai passé", @"suis passé" ],
        @"rentrer" : @[ @"ai rentré", @"suis rentré" ],
        @"retourner" : @[ @"ai retourné", @"suis retourné" ],
        @"sortir" : @[ @"ai sorti", @"suis sorti" ],
    };
    for (NSString *lemma in dualAuxiliaryForms) {
        NSArray *forms = [self.engine getFrenchConjugations:lemma context:@"je le" maxResults:40];
        NSArray *expected = dualAuxiliaryForms[lemma];
        XCTAssertLessThan([forms indexOfObject:expected[0]], [forms indexOfObject:expected[1]]);
    }

    NSArray *motionContext = [self.engine getFrenchConjugations:@"sortir" context:@"je" maxResults:40];
    XCTAssertLessThan([motionContext indexOfObject:@"suis sorti"], [motionContext indexOfObject:@"ai sorti"]);

    NSArray *reflexiveContext = [self.engine getFrenchConjugations:@"rentrer" context:@"elle se" maxResults:40];
    XCTAssertLessThan([reflexiveContext indexOfObject:@"est rentrée"], [reflexiveContext indexOfObject:@"a rentré"]);
}

- (void)testNegationPreservesSubjectRanking {
    NSArray *jeForms = [self.engine getFrenchConjugations:@"aller" context:@"je ne" maxResults:8];
    XCTAssertEqualObjects(jeForms.firstObject, @"vais");

    NSArray *nousForms = [self.engine getFrenchConjugations:@"aller" context:@"nous n’" maxResults:8];
    XCTAssertEqualObjects(nousForms.firstObject, @"allons");
}

- (void)testPronounContextRanksDualAuxiliaries {
    NSArray *directObject = [self.engine getFrenchConjugations:@"monter" context:@"elle la" maxResults:40];
    XCTAssertLessThan([directObject indexOfObject:@"a monté"], [directObject indexOfObject:@"est montée"]);

    NSArray *pluralObject = [self.engine getFrenchConjugations:@"descendre" context:@"nous les" maxResults:40];
    XCTAssertLessThan([pluralObject indexOfObject:@"avons descendu"], [pluralObject indexOfObject:@"sommes descendus"]);

    NSArray *reflexive = [self.engine getFrenchConjugations:@"sortir" context:@"ils se" maxResults:40];
    XCTAssertLessThan([reflexive indexOfObject:@"sont sortis"], [reflexive indexOfObject:@"ont sorti"]);
}

- (void)testElidedContextRanksConjugations {
    NSArray *jeForms = [self.engine getFrenchConjugations:@"aller" context:@"j’" maxResults:8];
    XCTAssertEqualObjects(jeForms.firstObject, @"vais");

    NSArray *ilForms = [self.engine getFrenchConjugations:@"venir" context:@"qu’il" maxResults:8];
    XCTAssertEqualObjects(ilForms.firstObject, @"vient");

    NSArray *ellesForms = [self.engine getFrenchConjugations:@"aller" context:@"qu’elles" maxResults:8];
    XCTAssertEqualObjects(ellesForms.firstObject, @"vont");

    NSArray *elidedObject = [self.engine getFrenchConjugations:@"sortir" context:@"je l’" maxResults:40];
    XCTAssertLessThan([elidedObject indexOfObject:@"ai sorti"], [elidedObject indexOfObject:@"suis sorti"]);
}

- (void)testElidedContextIsRecordedAndMerged {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller recordCommittedWord:@"j’"];
    XCTAssertEqualObjects([controller recentContext], @"j'");

    [controller recordCommittedWord:@"aime"];
    XCTAssertEqualObjects([controller recentContext], @"j'aime");

    [controller resetContext];
    [controller recordCommittedWord:@"je"];
    [controller recordCommittedWord:@"n’"];
    XCTAssertEqualObjects([controller recentContext], @"je n'");
}

- (void)testSubjectContextRanksConjugations {
    NSArray *nousForms = [self.engine getFrenchConjugations:@"all" context:@"nous" maxResults:8];
    XCTAssertEqualObjects(nousForms.firstObject, @"allons");

    NSArray *ellesForms = [self.engine getFrenchConjugations:@"all" context:@"elles" maxResults:8];
    XCTAssertEqualObjects(ellesForms.firstObject, @"vont");
    XCTAssertTrue([ellesForms containsObject:@"sont allées"]);
}

- (void)testSpellingCorrections {
    XCTAssertTrue([[self.engine getFrenchSpellingCorrections:@"ecloe" maxResults:8] containsObject:@"école"]);
    XCTAssertTrue([[self.engine getFrenchSpellingCorrections:@"bonjoru" maxResults:8] containsObject:@"bonjour"]);
}

- (void)testCandidateMergeDeduplicatesEquivalentSpellings {
    NSString *decomposedAlle = [@"allé" decomposedStringWithCanonicalMapping];
    NSArray *merged = [self.engine mergeFrenchCandidateGroups:@[
        @[ @"allé", @"j’aime", @"École", @"cote", @"côte" ],
        @[ decomposedAlle, @"j'aime", @"école", @"allé" ],
    ]
                                                    maxResults:20];
    XCTAssertEqualObjects(merged, (@[ @"allé", @"j’aime", @"École", @"cote", @"côte" ]));
}

- (void)testCandidateMergePreservesSourcePriorityAndLimit {
    NSArray *merged = [self.engine mergeFrenchCandidateGroups:@[
        @[ @"vais", @"allons" ],
        @[ @"allons", @"aller", @"allée" ],
    ]
                                                    maxResults:3];
    XCTAssertEqualObjects(merged, (@[ @"vais", @"allons", @"aller" ]));
}

- (void)testFrequencyRankedWordsLeadWithoutSubjectContext {
    NSArray *candidates = [self.engine getFrenchCandidates:@"all"];
    XCTAssertLessThan([candidates indexOfObject:@"aller"], [candidates indexOfObject:@"vais"]);
    XCTAssertEqual(candidates.count, [NSSet setWithArray:candidates].count);
}

- (void)testExactCommonWordStaysFirstWithContext {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller recordCommittedWord:@"hier"];
    [controller setOriginalBuffer:@"je"];

    NSArray *candidates = [controller candidates:nil];

    XCTAssertEqualObjects(candidates.firstObject, @"je");
    XCTAssertLessThan([candidates indexOfObject:@"jeune"], [candidates indexOfObject:@"jetons"]);
    XCTAssertLessThan([candidates indexOfObject:@"jeu"], [candidates indexOfObject:@"jetons"]);
}

- (void)testContextConjugationStillLeadsForPrefix {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller recordCommittedWord:@"nous"];
    [controller setOriginalBuffer:@"all"];

    NSArray *candidates = [controller candidates:nil];

    XCTAssertEqualObjects(candidates.firstObject, @"allons");
}

- (void)testSingleLetterInputIgnoresContextConjugations {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller recordCommittedWord:@"je"];
    [controller setOriginalBuffer:@"p"];

    NSArray *candidates = [controller candidates:nil];

    // "parle" (a "je"-conjugated form of parler) would win if context-based conjugation
    // ranking kicked in on a single letter; "pas" is the actual most frequent French word
    // starting with "p" and should lead once the prefix is this short.
    XCTAssertEqualObjects(candidates.firstObject, @"pas");
}

- (void)testTwoLetterInputIgnoresContextConjugations {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller recordCommittedWord:@"je"];
    [controller setOriginalBuffer:@"mo"];

    NSArray *candidates = [controller candidates:nil];
    NSArray *withoutContext = [self.engine getFrenchCandidates:@"mo"];

    // "meurs" (mourir is simply the highest-frequency verb matching "mo") would win if
    // context-based conjugation ranking kicked in this early, even though the user was
    // visibly typing towards something else entirely. With the override correctly held
    // off, the result should match plain frequency-ranked candidates exactly.
    XCTAssertEqualObjects(candidates.firstObject, withoutContext.firstObject);
    XCTAssertNotEqualObjects(candidates.firstObject, @"meurs");
}

- (void)testNormalization {
    XCTAssertEqualObjects([self.engine normalizeFrenchText:@"ÉCOLE"], @"ecole");
    XCTAssertEqualObjects([self.engine normalizeFrenchText:@"J’AIME"], @"j'aime");
    XCTAssertEqualObjects([self.engine normalizeFrenchText:@"J‘AIME"], @"j'aime");
}

- (void)testEmptyKeyCharactersAreIgnored {
    TestInputController *controller = [[TestInputController alloc] init];
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                      location:NSZeroPoint
                                 modifierFlags:0
                                     timestamp:0
                                  windowNumber:0
                                       context:nil
                                    characters:@""
                   charactersIgnoringModifiers:@""
                                      isARepeat:NO
                                        keyCode:0];

    XCTAssertFalse([controller onKeyEvent:event client:nil]);
}

- (void)testCandidateIndexResetsWhenCandidateListRebuilds {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller setOriginalBuffer:@"ecole"];
    [controller candidates:nil];

    // Simulate having navigated away from the top of the list with the arrow keys.
    [controller setCurrentCandidateIndex:5];

    // Retyping (or backspacing) rebuilds the candidate list, which should reset the
    // selection back to the top instead of leaving the stale index from before.
    [controller setOriginalBuffer:@"ecole"];
    [controller candidates:nil];

    XCTAssertEqual([controller currentCandidateIndex], 1);
}

- (void)testCandidateSelectionChangedSyncsIndexToActualSelection {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller setOriginalBuffer:@"ecole"];
    NSArray *candidates = [controller candidates:nil];
    XCTAssertGreaterThan(candidates.count, 2);

    // A mouse click (or any framework-driven selection change) should update the
    // tracked index to match the candidate that was actually selected.
    [controller candidateSelectionChanged:[[NSAttributedString alloc] initWithString:candidates[2]]];

    XCTAssertEqual([controller currentCandidateIndex], 3);
}

- (void)testCandidatePreviewKeepsOriginalInsertionIndex {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller setOriginalBuffer:@"ecole"];

    [controller candidateSelectionChanged:[[NSAttributedString alloc] initWithString:@"é"]];

    XCTAssertEqual([controller insertionIndex], [controller originalBuffer].length);
}

- (void)testAutoHighlightedCandidateDoesNotOverwritePreeditText {
    TestInputController *controller = [[TestInputController alloc] init];
    [controller setOriginalBuffer:@"cont"];
    NSArray *candidates = [controller candidates:nil];
    XCTAssertGreaterThan(candidates.count, 0);

    // IMKCandidates fires candidateSelectionChanged: the instant a fresh list appears,
    // auto-highlighting the first entry - not because the user did anything. Previewing
    // that inline would silently rewrite "cont" into e.g. "continue" before it was asked
    // for, so this must not touch the marked text yet.
    [controller candidateSelectionChanged:[[NSAttributedString alloc] initWithString:candidates.firstObject]];
    XCTAssertEqual(controller.preeditCallCount, 0);

    // Once the user has actually navigated the candidate list, previewing the highlighted
    // candidate inline is the expected, tested behavior (see
    // testCandidatePreviewKeepsOriginalInsertionIndex).
    [controller setHasNavigatedCandidates:YES];
    [controller candidateSelectionChanged:[[NSAttributedString alloc] initWithString:candidates.firstObject]];
    XCTAssertEqualObjects(controller.lastPreeditString, candidates.firstObject);
}

- (void)testSpacedPunctuationGetsNarrowNoBreakSpaceBefore {
    TestInputController *controller = [[TestInputController alloc] init];
    FakeInsertClient *client = [[FakeInsertClient alloc] init];
    [controller setOriginalBuffer:@"bonjour"];

    [controller commitFrenchPunctuation:@"!" client:client];

    XCTAssertEqualObjects(client.insertedText, @"bonjour ! ");
}

- (void)testCommaAndPeriodGetTrailingSpaceOnly {
    TestInputController *controller = [[TestInputController alloc] init];
    FakeInsertClient *client = [[FakeInsertClient alloc] init];
    [controller setOriginalBuffer:@"bonjour"];

    [controller commitFrenchPunctuation:@"," client:client];

    XCTAssertEqualObjects(client.insertedText, @"bonjour, ");
}

- (void)testOtherPunctuationIsAppendedWithNoSpacing {
    TestInputController *controller = [[TestInputController alloc] init];
    FakeInsertClient *client = [[FakeInsertClient alloc] init];
    [controller setOriginalBuffer:@"exemple"];

    [controller commitFrenchPunctuation:@")" client:client];

    XCTAssertEqualObjects(client.insertedText, @"exemple)");
}

- (void)testSentenceEndingPunctuationResetsContextButNotOthers {
    TestInputController *controller = [[TestInputController alloc] init];
    FakeInsertClient *client = [[FakeInsertClient alloc] init];
    [controller recordCommittedWord:@"bonjour"];

    [controller setOriginalBuffer:@"monde"];
    [controller commitFrenchPunctuation:@"," client:client];
    XCTAssertEqualObjects([controller recentContext], @"bonjour monde");

    [controller setOriginalBuffer:@"fin"];
    [controller commitFrenchPunctuation:@"." client:client];
    XCTAssertNil([controller recentContext]);
}

@end
