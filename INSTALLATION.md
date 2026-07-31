# Installation

## Configuration requise

- macOS 13.5 ou version ultérieure
- Mac Apple Silicon ou Intel

## Installation depuis GitHub

1. Téléchargez `Plume-Francaise-1.0.0.pkg` depuis la page Releases.
2. Ouvrez le paquet et suivez les étapes de l’installateur.
3. Ouvrez **Réglages Système → Clavier → Sources d’entrée**.
4. Ajoutez **Plume Française** dans la section Français si elle n’est pas déjà active.

L’archive `Plume-Francaise.zip` reste disponible pour une
installation manuelle dans `~/Library/Input Methods`.

Si le dossier `Input Methods` n’existe pas, créez-le dans le dossier
`Bibliothèque` de votre compte.

## Enregistrement manuel

Si la méthode de saisie n’apparaît pas après la reconnexion, ouvrez Terminal et
exécutez :

```sh
mkdir -p "$HOME/Library/Input Methods"
ditto Plume-Francaise.app "$HOME/Library/Input Methods/Plume-Francaise.app"
xattr -dr com.apple.quarantine "$HOME/Library/Input Methods/Plume-Francaise.app"
"$HOME/Library/Input Methods/Plume-Francaise.app/Contents/MacOS/PlumeFrancaise" --install
```

Ouvrez ensuite de nouveau les réglages des sources d’entrée.

## Première utilisation

Sélectionnez l’icône de saisie dans la barre des menus, puis choisissez
**Plume Française**. Essayez `ecole`, `jaime` ou `nous all`.

## Mise à jour

Quittez les applications dans lesquelles la méthode de saisie est active,
remplacez l’ancienne application dans `~/Library/Input Methods`, puis
reconnectez-vous à votre compte macOS.

## Désinstallation

Retirez d’abord la source d’entrée dans les Réglages Système, puis placez
`~/Library/Input Methods/Plume-Francaise.app` dans la Corbeille.
Les substitutions personnelles se trouvent dans :

```text
~/Library/Application Support/PlumeFrancaise
```
