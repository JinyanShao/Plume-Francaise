# Plume Française

[![CI](https://github.com/JinyanShao/Plume-Francaise/actions/workflows/ci.yml/badge.svg)](https://github.com/JinyanShao/Plume-Francaise/actions/workflows/ci.yml)

Plume Française is a native macOS input method for writing French with accents, typographic punctuation, spelling corrections, and context-aware suggestions. It works locally on the Mac.

## See It in Action

![Plume Française suggesting French text](docs/images/apercu.png)

Type without stopping to enter every accent, then choose the intended candidate:

```text
ecole       →  école
jaime       →  j’aime
nous all    →  nous allons
```

## Features

- Completes missing accents and preserves the input's capitalization.
- Converts French elisions to the typographic apostrophe (`’`).
- Applies French spacing before `;`, `:`, `!`, and `?`.
- Suggests spelling corrections for missing accents, transposed letters, and common mistakes.
- Suggests conjugations for 405 common verbs in the present, passé composé, imparfait, and futur simple.
- Uses the preceding subject or object pronoun to rank relevant verb forms.
- Supports personal substitutions stored on the Mac.
- Runs natively on both Apple Silicon and Intel Macs.

## Installation

Plume Française requires macOS 13.5 or later.

1. Download `Plume-Francaise-1.0.0.pkg` from the [Releases page](https://github.com/JinyanShao/Plume-Francaise/releases).
2. Open the package and follow the installer.
3. Open **System Settings → Keyboard → Input Sources**.
4. Add **Plume Française** under French if it is not already enabled.
5. Select Plume Française from the input menu in the macOS menu bar.

A ZIP archive is also available for manual installation in `~/Library/Input Methods`. See [INSTALLATION.md](INSTALLATION.md) for manual registration, updating, and uninstalling.

## Usage

Start typing in any application after selecting Plume Française as the active input source. The candidate window updates as you type.

- Press the up or down arrow to move through candidates.
- Press a number from `1` to `9` to select a candidate on the current page.
- Press Space to commit the current candidate and insert a space.
- Press Return to commit without adding a space.
- Press Escape to cancel the current composition.

French punctuation is formatted when committed. For example, typing `bonjour!` produces a narrow non-breaking space before the exclamation mark.

Personal substitutions can be managed from the input method's preferences. Their keys are matched without regard to accents or capitalization.

## More Examples

| Input | Suggested output | What it demonstrates |
| --- | --- | --- |
| `ecole` | `école` | Missing accent |
| `jaime` | `j’aime` | Elision and typographic apostrophe |
| `ca` | `ça` | French spelling ranked before less likely alternatives |
| `nous all` | `nous allons` | Subject-aware conjugation |
| `je suis all` | `je suis allé` | Passé composé suggestion |
| `bonjour!` | `bonjour ! ` | French punctuation spacing |

Suggestions depend on the available dictionary entries and the recent words in the current typing session.

## Privacy

Plume Française does not send typed text, candidate queries, or writing context to a remote service. Conversion and ranking use the dictionary bundled with the application.

Personal substitutions are stored locally in:

```text
~/Library/Application Support/PlumeFrancaise/substitutions.sqlite3
```

Recent words used for contextual ranking are kept in the running input-method process. There is no account, cloud synchronization, analytics service, or remote language model involved in text conversion.

The preferences page has a "Check for updates" button. It is the only network request Plume Française ever makes, only runs when clicked, and only asks GitHub for the latest release number — no typed text, substitutions, or identifying information is sent.

See [PRIVACY.md](PRIVACY.md) for the project's privacy statement.

## How It Works

```text
keyboard input
    → InputMethodKit controller
    → conversion engine
    → bundled French dictionary + recent local context
    → macOS candidate window
    → selected text inserted into the active application
```

The `InputController` receives key events from macOS and manages composition, punctuation, recent words, and candidate selection. `ConversionEngine` normalizes the input and combines exact dictionary matches, personal substitutions, conjugations, spelling corrections, and context predictions into a deduplicated candidate list.

The dictionary is a bundled SQLite database. Conjugation data is derived from Morphalou 3.1; the import and database-building scripts live in `dictionary/`.

## Building from Source

You need macOS, Xcode, CocoaPods, and Git.

```sh
git clone https://github.com/JinyanShao/Plume-Francaise.git
cd Plume-Francaise
pod install
open PlumeFrancaise.xcworkspace
```

Build the `PlumeFrancaise` scheme in Xcode, or create a Release build from the command line:

```sh
bash build.sh
```

The script writes build output under `/tmp/PlumeFrancaise`. To build an installer package, run:

```sh
bash package/build-package.bash
```

No credentials or environment file are required.

## Architecture

The application is written in Objective-C and Objective-C++ on top of InputMethodKit and AppKit.

- `src/InputController.mm` handles macOS input events, composition, and the candidate window.
- `src/ConversionEngine.mm` performs normalization, lookup, correction, conjugation, and ranking.
- `dictionary/french.sqlite3` contains the vocabulary, frequency, context, and conjugation data used at runtime.
- `web/` and `src/WebServer.m` provide the local preferences interface over a loopback-only web server.
- `package/` contains the macOS installer scripts.

Runtime dependencies are managed with CocoaPods: FMDB for SQLite access, GCDWebServer for the local preferences interface, and MDCDamerauLevenshtein for spelling-distance calculations.

## Testing

Run the native test suite with:

```sh
bash unit-tests.sh
```

Source formatting and a Release build can be checked separately:

```sh
sh format-code.sh
bash build.sh
```

The regression tests cover normalization, accent and apostrophe handling, conjugation ranking, contextual suggestions, candidate selection, and punctuation behavior.

## Compatibility

- macOS 13.5 or later
- Apple Silicon and Intel Macs
- French input through macOS InputMethodKit

Plume Française is macOS-specific and is not available for Windows, Linux, iOS, or Android.

## Known Limitations

- The bundled dictionary does not cover every French word, regional spelling, or specialist term.
- Conjugation suggestions are limited to the included verbs and tenses.
- Personal substitutions and context do not synchronize between Macs.
- Some applications handle third-party input methods differently; candidate-window placement and key handling may vary.

## Licence

Plume Française is licensed under the GNU GPL v3.0. See [COPYING.md](COPYING.md) and [LICENSE](LICENSE). Conjugation data derived from Morphalou 3.1 retains its stated LGPL-LR licensing.
