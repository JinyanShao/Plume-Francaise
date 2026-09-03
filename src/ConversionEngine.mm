#import "ConversionEngine.h"

extern NSUserDefaults *preference;

static NSString *EtrePresentWordForSubject(NSString *subject) {
    static NSDictionary *forms;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        forms = @{
            @"je" : @"suis", @"tu" : @"es", @"il" : @"est", @"elle" : @"est", @"on" : @"est",
            @"nous" : @"sommes", @"vous" : @"etes", @"ils" : @"sont", @"elles" : @"sont"
        };
    });
    return forms[subject];
}

static NSString *AvoirPresentWordForSubject(NSString *subject) {
    static NSDictionary *forms;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        forms = @{
            @"je" : @"ai", @"tu" : @"as", @"il" : @"a", @"elle" : @"a", @"on" : @"a",
            @"nous" : @"avons", @"vous" : @"avez", @"ils" : @"ont", @"elles" : @"ont"
        };
    });
    return forms[subject];
}

@implementation ConversionEngine {
    FMDatabaseQueue *_frenchDbQueue;
    FMDatabaseQueue *_subDbQueue;
}

+ (instancetype)sharedEngine {
    static dispatch_once_t once;
    static ConversionEngine *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
        [sharedInstance loadPreparedData];
    });
    return sharedInstance;
}

- (void)loadPreparedData {
    [self initFrenchDatabase];
    [self initSubstitutionDatabase];
    self.substitutions = [self loadSubstitutionsFromDB];
}

- (void)initFrenchDatabase {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"french" ofType:@"sqlite3"];
    if (!path)
        path = [[NSBundle bundleForClass:self.class] pathForResource:@"french" ofType:@"sqlite3"];
    if (!path) {
        NSLog(@"[PlumeFrancaise] French dictionary not found");
        return;
    }
    _frenchDbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
}

- (void)initSubstitutionDatabase {
    NSString *applicationSupport = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *supportDir = [applicationSupport stringByAppendingPathComponent:@"PlumeFrancaise"];
    NSString *legacySupportDir = [applicationSupport stringByAppendingPathComponent:@"JinyanShaoFrenchInputMethod"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:supportDir] && [fileManager fileExistsAtPath:legacySupportDir]) {
        if (![fileManager moveItemAtPath:legacySupportDir toPath:supportDir error:&error])
            NSLog(@"[PlumeFrancaise] Failed to migrate legacy substitutions directory: %@", error);
    }
    if (![fileManager createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:&error])
        NSLog(@"[PlumeFrancaise] Failed to create Application Support directory at %@: %@", supportDir, error);
    NSString *dbPath = [supportDir stringByAppendingPathComponent:@"substitutions.sqlite3"];
    _subDbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [_subDbQueue inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS substitutions (key TEXT PRIMARY KEY, value TEXT)"])
            NSLog(@"[PlumeFrancaise] Failed to create substitutions table: %@", db.lastError);
    }];
}

- (NSString *)normalizeFrenchText:(NSString *)text {
    if (!text)
        return @"";
    NSString *normalized = [[[text lowercaseString] stringByReplacingOccurrencesOfString:@"‘"
                                                                              withString:@"'"] stringByReplacingOccurrencesOfString:@"’"
                                                                                                                         withString:@"'"];
    return [normalized stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"fr"]];
}

- (NSString *)candidate:(NSString *)candidate matchingCaseOfInput:(NSString *)input {
    if (candidate.length == 0 || input.length == 0)
        return candidate;
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[input characterAtIndex:0]]) {
        return [candidate stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[candidate substringToIndex:1] uppercaseString]];
    }
    return candidate;
}

// Returns @{"candidate": ..., "frequency": ...} for the best elision match, or nil. The
// frequency (of the word after the apostrophe) lets the caller weigh this against plain
// dictionary prefix matches instead of always trusting it blindly - "o" is a real word, but
// treating "m'o" as more relevant than "mon" just because it's an elision would be wrong.
- (NSDictionary *)elidedCandidateForInput:(NSString *)input {
    NSString *normalized = [self normalizeFrenchText:input];
    for (NSString *prefix in @[ @"qu", @"l", @"j", @"c", @"d", @"n", @"m", @"s", @"t" ]) {
        if (![normalized hasPrefix:prefix] || normalized.length <= prefix.length)
            continue;
        NSString *remainder = [normalized substringFromIndex:prefix.length];
        // The user may have typed the apostrophe themselves (e.g. "c" + "'" + "est") rather
        // than letting it be inferred from letters alone ("cest"); either way the remainder
        // to look up is whatever comes after it.
        if ([remainder hasPrefix:@"'"])
            remainder = [remainder substringFromIndex:1];
        if (remainder.length == 0)
            continue;
        __block BOOL isWord = NO;
        __block long long frequency = 0;
        [_frenchDbQueue inDatabase:^(FMDatabase *db) {
            FMResultSet *result = [db executeQuery:@"SELECT frequency FROM french_words WHERE normalized = ? LIMIT 1", remainder];
            if ([result next]) {
                isWord = YES;
                frequency = [result longLongIntForColumn:@"frequency"];
            }
            [result close];
        }];
        if (isWord) {
            NSString *candidate = [NSString stringWithFormat:@"%@’%@", prefix, remainder];
            return @{
                @"candidate" : [self candidate:candidate matchingCaseOfInput:input],
                @"frequency" : @(frequency),
            };
        }
    }
    return nil;
}

- (NSArray *)getFrenchConjugations:(NSString *)input maxResults:(NSInteger)max {
    return [self getFrenchConjugations:input context:nil maxResults:max];
}

- (NSString *)subjectForContext:(NSString *)context {
    NSDictionary *subjects = @{
        @"je" : @"je",
        @"j'" : @"je",
        @"tu" : @"tu",
        @"il" : @"il",
        @"qu'il" : @"il",
        @"elle" : @"elle",
        @"qu'elle" : @"elle",
        @"on" : @"on",
        @"qu'on" : @"on",
        @"nous" : @"nous",
        @"vous" : @"vous",
        @"ils" : @"ils",
        @"qu'ils" : @"ils",
        @"elles" : @"elles",
        @"qu'elles" : @"elles",
    };
    NSArray *parts = [[self normalizeFrenchText:context ?: @""] componentsSeparatedByString:@" "];
    for (NSString *part in [parts reverseObjectEnumerator]) {
        NSString *subject = subjects[part];
        if (subject)
            return subject;
    }
    return @"";
}

- (BOOL)contextPrefersAvoir:(NSString *)context {
    NSArray *parts = [[self normalizeFrenchText:context ?: @""] componentsSeparatedByString:@" "];
    if ([self subjectForContext:context].length == 0)
        return NO;
    NSSet *directObjects = [NSSet setWithArray:@[ @"le", @"la", @"les", @"l'" ]];
    NSString *lastPart = parts.lastObject;
    return [directObjects containsObject:lastPart];
}

// Past participles agree in gender with the subject only for être-based compound tenses
// (présent, imparfait and futur simple never vary by gender at all). The dictionary already
// stores the correct form for il/elle/nous/vous/ils/elles, since those subjects have a fixed
// grammatical gender regardless of who is speaking - only je/tu/on depend on a preference the
// user sets, and the dictionary always stores their masculine form. When the user has said
// they're feminine, the regular "+e" rule applies to whatever the last word of the phrase is
// (the participle itself, whether or not the auxiliary is included alongside it), so this
// works uniformly for the full dictionary phrase ("suis allé" -> "suis allée") and for the
// bare participle used once the auxiliary has already been typed separately ("allé" ->
// "allée").
- (NSString *)applyGenderAgreementIfNeeded:(NSString *)form subject:(NSString *)subject usesEtre:(BOOL)usesEtre {
    if (!usesEtre || form.length == 0)
        return form;
    NSSet *subjectsNeedingPreference = [NSSet setWithArray:@[ @"je", @"tu", @"on" ]];
    if (![subjectsNeedingPreference containsObject:subject])
        return form;
    if (![[preference stringForKey:@"genderAgreement"] isEqualToString:@"feminine"])
        return form;
    return [form stringByAppendingString:@"e"];
}

// If the user already typed the auxiliary itself (e.g. "je" then "suis", committed
// separately, then starts typing the verb), the context's last word IS that auxiliary -
// not just a hint that one might be needed. In that case the useful suggestion is the bare
// past participle ("allé"), not the full "suis allé" phrase stored in the dictionary, which
// would duplicate the "suis" already sitting in the document. Returns nil unless the last
// context word exactly matches the present-tense être/avoir form for the given subject.
- (NSString *)participleForAuxiliaryAlreadyTypedInContext:(NSString *)context subject:(NSString *)subject lemmaPattern:(NSString *)pattern {
    if (subject.length == 0)
        return nil;
    NSString *lastPart = [[self normalizeFrenchText:context ?: @""] componentsSeparatedByString:@" "].lastObject;
    if (lastPart.length == 0)
        return nil;
    BOOL usesEtre = [EtrePresentWordForSubject(subject) isEqualToString:lastPart];
    if (!usesEtre && ![AvoirPresentWordForSubject(subject) isEqualToString:lastPart])
        return nil;

    __block NSString *participle = nil;
    NSString *auxiliaryPrefix = [lastPart stringByAppendingString:@" "];
    [_frenchDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT form, form_normalized FROM french_conjugations "
                                               @"WHERE lemma_normalized LIKE ? AND subject = ? AND tense = 'past_compound' "
                                               @"ORDER BY verb_frequency DESC LIMIT 20",
                                               pattern, subject];
        while ([result next]) {
            if ([[result stringForColumn:@"form_normalized"] hasPrefix:auxiliaryPrefix]) {
                participle = [[result stringForColumn:@"form"] substringFromIndex:auxiliaryPrefix.length];
                break;
            }
        }
        [result close];
    }];
    return [self applyGenderAgreementIfNeeded:participle subject:subject usesEtre:usesEtre];
}

- (NSArray *)getFrenchConjugations:(NSString *)input context:(NSString *)context maxResults:(NSInteger)max {
    if (!_frenchDbQueue || input.length == 0 || max <= 0)
        return @[];
    NSString *normalized = [self normalizeFrenchText:input];
    NSString *pattern = [NSString stringWithFormat:@"%@%%", normalized];
    NSString *subject = [self subjectForContext:context];
    BOOL preferAvoir = [self contextPrefersAvoir:context];
    __block NSMutableOrderedSet *forms = [NSMutableOrderedSet orderedSet];

    NSString *participleAfterAuxiliary = [self participleForAuxiliaryAlreadyTypedInContext:context subject:subject lemmaPattern:pattern];
    if (participleAfterAuxiliary.length > 0)
        [forms addObject:[self candidate:participleAfterAuxiliary matchingCaseOfInput:input]];

    [_frenchDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT form FROM french_conjugations "
                                               @"WHERE lemma_normalized LIKE ? OR form_normalized LIKE ? "
                                               @"ORDER BY CASE WHEN subject = ? THEN 0 ELSE 1 END, "
                                               @"CASE WHEN lemma_normalized = ? THEN 0 ELSE 1 END, "
                                               @"CASE WHEN ? AND rank BETWEEN 320 AND 328 THEN rank - 20 "
                                               @"WHEN ? AND rank BETWEEN 300 AND 308 THEN rank + 20 ELSE rank END, "
                                               @"verb_frequency DESC LIMIT ?",
                                               pattern, pattern, subject, normalized, @(preferAvoir), @(preferAvoir),
                                               @(MAX(max * 4, 40))];
        NSString *etreWord = EtrePresentWordForSubject(subject);
        NSString *etrePrefix = etreWord ? [etreWord stringByAppendingString:@" "] : nil;
        while ([result next]) {
            NSString *rawForm = [result stringForColumn:@"form"];
            BOOL usesEtre = etrePrefix && [[self normalizeFrenchText:rawForm] hasPrefix:etrePrefix];
            NSString *agreedForm = [self applyGenderAgreementIfNeeded:rawForm subject:subject usesEtre:usesEtre];
            NSString *form = [self candidate:agreedForm matchingCaseOfInput:input];
            if (form.length > 0)
                [forms addObject:form];
            if (forms.count >= (NSUInteger)max)
                break;
        }
        [result close];
    }];
    return forms.array;
}

- (NSArray *)getFrenchSpellingCorrections:(NSString *)input maxResults:(NSInteger)max {
    if (!_frenchDbQueue || input.length < 3 || max <= 0)
        return @[];
    NSString *normalized = [self normalizeFrenchText:input];
    NSInteger length = normalized.length;
    NSUInteger maximumDistance = length <= 5 ? 1 : 2;
    __block NSMutableArray *matches = [NSMutableArray array];
    [_frenchDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT normalized, word, frequency FROM french_words "
                                               @"WHERE word_length BETWEEN ? AND ? ORDER BY frequency DESC LIMIT 1200",
                                               @(MAX(1, length - 2)), @(length + 2)];
        while ([result next]) {
            NSString *candidateNormalized = [result stringForColumn:@"normalized"];
            NSUInteger distance = [normalized mdc_damerauLevenshteinDistanceTo:candidateNormalized];
            if (distance <= maximumDistance) {
                [matches addObject:@{
                    @"word" : [result stringForColumn:@"word"],
                    @"distance" : @(distance),
                    @"frequency" : @([result longLongIntForColumn:@"frequency"])
                }];
            }
        }
        [result close];
    }];
    [matches sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSComparisonResult distanceOrder = [left[@"distance"] compare:right[@"distance"]];
        if (distanceOrder != NSOrderedSame)
            return distanceOrder;
        return [right[@"frequency"] compare:left[@"frequency"]];
    }];
    NSMutableOrderedSet *corrections = [NSMutableOrderedSet orderedSet];
    for (NSDictionary *match in matches) {
        [corrections addObject:[self candidate:match[@"word"] matchingCaseOfInput:input]];
        if (corrections.count >= (NSUInteger)max)
            break;
    }
    return corrections.array;
}

- (NSArray *)mergeFrenchCandidateGroups:(NSArray *)groups maxResults:(NSInteger)max {
    if (max <= 0)
        return @[];
    NSMutableArray *merged = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSArray *group in groups) {
        for (NSString *candidate in group) {
            if (![candidate isKindOfClass:NSString.class] || candidate.length == 0)
                continue;
            NSString *key = [[[candidate precomposedStringWithCanonicalMapping] lowercaseString]
                stringByReplacingOccurrencesOfString:@"'"
                                           withString:@"’"];
            key = [key stringByReplacingOccurrencesOfString:@"‘" withString:@"’"];
            if ([seen containsObject:key])
                continue;
            [seen addObject:key];
            [merged addObject:candidate];
            if (merged.count >= (NSUInteger)max)
                return merged.copy;
        }
    }
    return merged.copy;
}

- (NSArray *)getFrenchCandidates:(NSString *)originalInput {
    if (!_frenchDbQueue || originalInput.length == 0)
        return originalInput.length > 0 ? @[ originalInput ] : @[];

    NSString *normalized = [self normalizeFrenchText:originalInput];
    NSString *pattern = [NSString stringWithFormat:@"%@%%", normalized];
    __block NSMutableArray *exactMatches = [NSMutableArray array];
    __block NSMutableArray *prefixMatches = [NSMutableArray array];
    __block BOOL hasExactMatch = NO;
    __block long long topPrefixMatchFrequency = 0;
    [_frenchDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT normalized, word, frequency FROM french_words WHERE normalized LIKE ? "
                                               @"ORDER BY CASE WHEN normalized = ? THEN 0 ELSE 1 END, frequency DESC LIMIT 40",
                                               pattern, normalized];
        while ([result next]) {
            BOOL isExactMatch = [[result stringForColumn:@"normalized"] isEqualToString:normalized];
            if (isExactMatch)
                hasExactMatch = YES;
            NSString *word = [self candidate:[result stringForColumn:@"word"] matchingCaseOfInput:originalInput];
            if (word.length > 0 && isExactMatch) {
                [exactMatches addObject:word];
            } else if (word.length > 0) {
                if (prefixMatches.count == 0)
                    topPrefixMatchFrequency = [result longLongIntForColumn:@"frequency"];
                [prefixMatches addObject:word];
            }
        }
        [result close];
    }];

    NSString *substitution = self.substitutions[normalized];
    NSDictionary *elidedInfo = [self elidedCandidateForInput:originalInput];
    NSString *elided = elidedInfo[@"candidate"];
    // An elision is only more useful than the dictionary's best plain prefix match when the
    // word it's built from is actually the more common one - otherwise a rare word that
    // happens to complete the elision (e.g. "o" for "m'o") would bury common words like "mon".
    BOOL elisionLeadsPrefixMatches =
        elided && (prefixMatches.count == 0 || [elidedInfo[@"frequency"] longLongValue] >= topPrefixMatchFrequency);
    NSArray *conjugations = [self getFrenchConjugations:originalInput maxResults:12];
    NSArray *corrections = hasExactMatch ? @[] : [self getFrenchSpellingCorrections:originalInput maxResults:8];
    return [self mergeFrenchCandidateGroups:@[
        substitution ? @[ substitution ] : @[],
        exactMatches,
        elisionLeadsPrefixMatches ? @[ elided ] : @[],
        prefixMatches,
        elided && !elisionLeadsPrefixMatches ? @[ elided ] : @[],
        conjugations,
        corrections,
        @[ originalInput ],
    ]
                                  maxResults:50];
}

- (NSArray *)predictFrenchWordsForContext:(NSString *)context prefixFilter:(NSString *)prefix maxResults:(NSInteger)max {
    if (!_frenchDbQueue || context.length == 0 || max <= 0)
        return @[];

    NSArray *parts = [[self normalizeFrenchText:context] componentsSeparatedByString:@" "];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length > 0)
            [words addObject:part];
    }

    NSString *normalizedPrefix = [self normalizeFrenchText:prefix ?: @""];
    __block NSMutableOrderedSet *predictions = [NSMutableOrderedSet orderedSet];
    [_frenchDbQueue inDatabase:^(FMDatabase *db) {
        NSInteger longest = MIN(3, words.count);
        for (NSInteger length = longest; length >= 1 && predictions.count < (NSUInteger)max; length--) {
            NSArray *suffix = [words subarrayWithRange:NSMakeRange(words.count - length, length)];
            NSString *normalizedContext = [suffix componentsJoinedByString:@" "];
            NSString *pattern = [NSString stringWithFormat:@"%@%%", normalizedPrefix];
            FMResultSet *result = [db executeQuery:@"SELECT next_word FROM french_ngrams "
                                                   @"WHERE context = ? AND next_word LIKE ? "
                                                   @"ORDER BY frequency DESC LIMIT ?",
                                                   normalizedContext, pattern, @(max - predictions.count)];
            while ([result next]) {
                NSString *word = [self candidate:[result stringForColumn:@"next_word"] matchingCaseOfInput:prefix];
                if (word.length > 0)
                    [predictions addObject:word];
            }
            [result close];
        }
    }];
    return predictions.array;
}

- (NSDictionary *)loadSubstitutionsFromDB {
    if (!_subDbQueue)
        return @{};
    __block NSMutableDictionary *substitutions = [NSMutableDictionary dictionary];
    [_subDbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *result = [db executeQuery:@"SELECT key, value FROM substitutions"];
        while ([result next])
            substitutions[[result stringForColumn:@"key"]] = [result stringForColumn:@"value"];
        [result close];
    }];
    return substitutions.copy;
}

- (NSDictionary *)allSubstitutions {
    return [self loadSubstitutionsFromDB];
}

- (void)addSubstitution:(NSString *)key value:(NSString *)value {
    if (!_subDbQueue)
        return;
    NSString *normalizedKey = [self normalizeFrenchText:key];
    [_subDbQueue inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"INSERT OR REPLACE INTO substitutions (key, value) VALUES (?, ?)", normalizedKey, value])
            NSLog(@"[PlumeFrancaise] Failed to save substitution for %@: %@", normalizedKey, db.lastError);
    }];
    self.substitutions = [self loadSubstitutionsFromDB];
}

- (void)removeSubstitution:(NSString *)key {
    if (!_subDbQueue)
        return;
    NSString *normalizedKey = [self normalizeFrenchText:key];
    [_subDbQueue inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"DELETE FROM substitutions WHERE key = ?", normalizedKey])
            NSLog(@"[PlumeFrancaise] Failed to remove substitution for %@: %@", normalizedKey, db.lastError);
    }];
    self.substitutions = [self loadSubstitutionsFromDB];
}

@end
