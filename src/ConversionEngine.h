#import "FMDB.h"
#import <Cocoa/Cocoa.h>
#import "MDCDamerauLevenshtein.h"

@interface ConversionEngine : NSObject

+ (instancetype)sharedEngine;

- (NSArray *)getFrenchCandidates:(NSString *)originalInput;
- (NSArray *)getFrenchConjugations:(NSString *)input maxResults:(NSInteger)max;
- (NSArray *)getFrenchConjugations:(NSString *)input context:(NSString *)context maxResults:(NSInteger)max;
- (NSArray *)getFrenchSpellingCorrections:(NSString *)input maxResults:(NSInteger)max;
- (NSArray *)predictFrenchWordsForContext:(NSString *)context prefixFilter:(NSString *)prefix maxResults:(NSInteger)max;
- (NSArray *)mergeFrenchCandidateGroups:(NSArray *)groups maxResults:(NSInteger)max;
- (NSString *)normalizeFrenchText:(NSString *)text;

- (NSDictionary *)allSubstitutions;
- (void)addSubstitution:(NSString *)key value:(NSString *)value;
- (void)removeSubstitution:(NSString *)key;

// Written from the web server's background queue (add/removeSubstitution) and read from
// the main thread while typing (getFrenchCandidates:). Keep this atomic (the default) and
// always replace the whole dictionary rather than mutating it in place, so a reader never
// observes a partially-updated value.
@property NSDictionary *substitutions;

@end
