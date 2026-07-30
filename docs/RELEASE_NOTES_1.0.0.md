# Jinyan Shao French Input Method 1.0.0

Première version publique de la méthode de saisie française native pour macOS.

## Points forts

- Accents intelligents : `ecole` → `école`
- Apostrophes françaises : `jaime` → `j’aime`
- Correction locale des fautes courantes
- Prédictions classées selon le contexte
- 405 verbes fréquents dans quatre temps
- Passé composé avec `être` et `avoir` pour les verbes à double auxiliaire
- Ordre des auxiliaires adapté aux pronoms compléments `le`, `la` et `les`
- Universal : Apple Silicon et Intel
- Fonctionnement local, sans télémétrie ni transmission du texte saisi

## Installation

1. Téléchargez `JinyanShao-FrenchInputMethod-1.0.0.pkg`.
2. Ouvrez le paquet et suivez les étapes de l’installateur.
3. Activez la méthode dans **Réglages Système → Clavier → Sources d’entrée** si nécessaire.

L’archive ZIP permet également une installation manuelle dans
`~/Library/Input Methods`.

Le guide complet et la procédure d’enregistrement manuel se trouvent dans
`INSTALLATION.md`.

## Fichiers de la publication

- `JinyanShao-FrenchInputMethod-1.0.0.pkg` — paquet d’installation macOS
- `JinyanShao-FrenchInputMethod.zip` — application Universal prête à installer
- `JinyanShao-FrenchInputMethod-source.zip` — archive complète du code source
- `SHA256SUMS.txt` — empreintes SHA-256 des trois fichiers distribués

## Vérifications

- Architectures `arm64` et `x86_64`
- Signature ad hoc vérifiée après extraction
- Base de données SQLite vérifiée
- 405 verbes et 14 602 formes contextuelles

L’application utilise actuellement une signature ad hoc et n’est pas encore
notariée par Apple.
