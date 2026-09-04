#import "InputApplicationDelegate.h"

extern NSUserDefaults *preference;

static NSString *const kCommitWordWithSpaceKey = @"commitWordWithSpace";
static NSString *const kGenderAgreementKey = @"genderAgreement";

@implementation InputApplicationDelegate {
    NSMenuItem *_commitWordWithSpaceItem;
    NSMenuItem *_genderUnspecifiedItem;
    NSMenuItem *_genderMasculineItem;
    NSMenuItem *_genderFeminineItem;
}

- (NSMenu *)menu {
    return _menu;
}

- (void)awakeFromNib {
    NSMenuItem *preferenceMenuItem = [_menu itemWithTitle:@"Préférences"];
    NSMenuItem *aboutMenuItem = [_menu itemWithTitle:@"À propos"];

    if (preferenceMenuItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        preferenceMenuItem.action = @selector(showIMEPreferences:);
#pragma clang diagnostic pop
    }

    if (aboutMenuItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        aboutMenuItem.action = @selector(clickAbout:);
#pragma clang diagnostic pop
    }

    // Quick toggles so the two settings someone is most likely to flip on the fly
    // (spacing behavior, grammatical gender) don't require opening the full preferences
    // page - the page remains the source of truth and stays in sync since both read and
    // write the same shared NSUserDefaults.
    _commitWordWithSpaceItem = [_menu itemWithTitle:@"Valider le mot avec Espace"];
    _commitWordWithSpaceItem.target = self;
    _commitWordWithSpaceItem.action = @selector(toggleCommitWordWithSpace:);

    NSMenu *genreSubmenu = [_menu itemWithTitle:@"Genre"].submenu;
    _genderUnspecifiedItem = [genreSubmenu itemWithTitle:@"Non précisé"];
    _genderMasculineItem = [genreSubmenu itemWithTitle:@"Masculin"];
    _genderFeminineItem = [genreSubmenu itemWithTitle:@"Féminin"];
    for (NSMenuItem *item in @[ _genderUnspecifiedItem, _genderMasculineItem, _genderFeminineItem ]) {
        item.target = self;
        item.action = @selector(selectGenderAgreement:);
    }

    _menu.delegate = self;
}

// Refreshes the checkmarks right before the menu is shown, since the preferences page (a
// separate process-local UI for the same settings) could have changed them since the menu
// was last opened.
- (void)menuWillOpen:(NSMenu *)menu {
    if (menu != _menu)
        return;

    _commitWordWithSpaceItem.state = [preference boolForKey:kCommitWordWithSpaceKey] ? NSControlStateValueOn : NSControlStateValueOff;

    NSString *gender = [preference stringForKey:kGenderAgreementKey] ?: @"unspecified";
    _genderUnspecifiedItem.state = [gender isEqualToString:@"unspecified"] ? NSControlStateValueOn : NSControlStateValueOff;
    _genderMasculineItem.state = [gender isEqualToString:@"masculine"] ? NSControlStateValueOn : NSControlStateValueOff;
    _genderFeminineItem.state = [gender isEqualToString:@"feminine"] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)toggleCommitWordWithSpace:(NSMenuItem *)sender {
    [preference setBool:![preference boolForKey:kCommitWordWithSpaceKey] forKey:kCommitWordWithSpaceKey];
}

- (void)selectGenderAgreement:(NSMenuItem *)sender {
    NSDictionary *genderByTitle = @{
        @"Non précisé" : @"unspecified",
        @"Masculin" : @"masculine",
        @"Féminin" : @"feminine",
    };
    NSString *gender = genderByTitle[sender.title];
    if (gender)
        [preference setObject:gender forKey:kGenderAgreementKey];
}

@end
