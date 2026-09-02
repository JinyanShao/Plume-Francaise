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

@property NSDictionary *substitutions;

@end
