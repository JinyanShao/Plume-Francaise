# Jinyan Shao French Input Method

Une méthode de saisie macOS native, rapide et entièrement locale, conçue
exclusivement pour écrire en français.

![Aperçu de Jinyan Shao French Input Method](docs/images/apercu.png)

## Fonctionnalités

- Complétion intelligente des accents : `ecole` → `école`, `hotel` → `hôtel`
- Apostrophes typographiques françaises : `jaime` → `j’aime`
- Espacement français avant `;`, `:`, `!` et `?`
- Correction des accents manquants, inversions de lettres et fautes courantes
- Suggestions classées selon la fréquence et les mots précédents
- 405 verbes fréquents aux temps présent, passé composé, imparfait et futur simple
- Classement des conjugaisons selon le sujet : `nous all…` propose `allons` en premier
- Dictionnaire et historique de contexte conservés uniquement sur le Mac
- Application Universal compatible Apple Silicon et Intel

## Compatibilité

- macOS 13.5 ou version ultérieure
- Mac Apple Silicon ou Intel

## Installation

Téléchargez `JinyanShao-FrenchInputMethod.zip` depuis la page
[Releases](https://github.com/jinyanshao/JinyanShao-FrenchInputMethod/releases),
puis suivez le [guide d’installation détaillé](INSTALLATION.md).

Après l’installation, la méthode de saisie apparaît dans :

**Réglages Système → Clavier → Sources d’entrée**

## Utilisation

Saisissez un mot sans accent ou le début d’un mot, puis choisissez une
proposition avec les touches numériques.

| Saisie | Proposition |
| --- | --- |
| `ecole` | `école` |
| `lhomme` | `l’homme` |
| `ecloe` | `école` |
| `nous` puis `all` | `allons` |
| `elle` puis `aller` | `va`, `allait`, `ira`, `est allée` |

## Confidentialité

Le texte saisi n’est envoyé à aucun serveur. Les candidats, les substitutions
personnelles et le contexte récent sont traités localement. Consultez la
[politique de confidentialité](PRIVACY.md) pour plus de détails.

## Compilation

La compilation depuis les sources nécessite Xcode et CocoaPods :

```sh
pod install
open JinyanShaoFrenchInputMethod.xcworkspace
```

Compilez ensuite le schéma `JinyanShaoFrenchInputMethod` en configuration
Release. Le projet produit une application Universal pour Apple Silicon et
Intel.

Commandes de vérification :

```sh
sh format-code.sh
sh unit-tests.sh
bash build.sh
```

## Documentation

- [Installation](INSTALLATION.md)
- [Confidentialité](PRIVACY.md)
- [Historique des versions](CHANGELOG.md)
- [Notes de publication 1.0.0](docs/RELEASE_NOTES_1.0.0.md)

## Auteur

Jinyan Shao<br>
[jinyanshao@proton.me](mailto:jinyanshao@proton.me)

## Licence

Le projet est distribué sous GNU GPL v3.0. Les données de conjugaison sont
dérivées de Morphalou 3.1, maintenu par ATILF/CNRS et distribué sous LGPL-LR.
Consultez [COPYING.md](COPYING.md) pour les attributions.

Le projet est basé sur le code source libre HallelujahIM. Les composants tiers
conservent leurs licences et mentions de copyright respectives.
