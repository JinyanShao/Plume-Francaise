# Installation

> **Technical preview:** la version actuelle utilise une signature ad hoc et
> n’est pas notarized par Apple. Elle est destinée à des personnes à l’aise avec
> l’examen et l’exécution de logiciels macOS open source en préversion
> technique.

## Configuration requise

- macOS 13.5 ou version ultérieure
- Mac Apple Silicon ou Intel

## Installation depuis GitHub

1. Téléchargez `Plume-Francaise-1.1.0.pkg` depuis la page Releases.
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
"$HOME/Library/Input Methods/Plume-Francaise.app/Contents/MacOS/PlumeFrancaise" --install
```

Ouvrez ensuite de nouveau les réglages des sources d’entrée.

## Dépannage pour les utilisateurs qui comprennent les implications

Si macOS bloque l’ouverture de l’application, cela est attendu pour une version
ad-hoc signed et non notarized. La suppression de l’attribut de quarantaine ne
fait pas partie de l’installation standard.

Si vous comprenez l’implication de sécurité et faites confiance à l’archive
téléchargée, vous pouvez retirer l’attribut de quarantaine manuellement :

```sh
xattr -dr com.apple.quarantine "$HOME/Library/Input Methods/Plume-Francaise.app"
```

macOS affiche systématiquement un avertissement générique pour toute méthode de
saisie tierce (« le développeur peut accéder à tout ce que vous saisissez »)
lorsque vous consultez ses réglages dans **Réglages Système → Clavier → Sources
d’entrée**. Ce message est affiché pour toutes les méthodes de saisie non
signées par Apple, quel que soit leur fonctionnement réel ; voir
[PRIVACY.md](PRIVACY.md) pour ce que fait réellement Plume Française.

Sur certaines versions récentes de macOS, activer une méthode de saisie tierce
pour la première fois peut provoquer la fermeture inattendue de l’application
au premier plan au moment du changement. Il s’agit d’un problème dans le
composant système `TextInputUIMacHelper` d’Apple qui affiche la bulle « méthode
de saisie changée », pas d’un problème de Plume Française ; rouvrez simplement
l’application concernée.

## Première utilisation

Sélectionnez l’icône de saisie dans la barre des menus, puis choisissez
**Plume Française**. Essayez `ecole`, `jaime` ou `nous all`.

## Mise à jour

La page de préférences (accessible depuis le menu de la méthode de saisie)
propose un bouton « Check for updates » qui indique si une nouvelle version est
disponible sur GitHub. C’est la seule requête réseau que l’application effectue,
et uniquement lorsque vous cliquez sur ce bouton.

Pour installer une nouvelle version : quittez les applications dans lesquelles
la méthode de saisie est active, remplacez l’ancienne application dans
`~/Library/Input Methods`, puis reconnectez-vous à votre compte macOS.

## Désinstallation

Retirez d’abord la source d’entrée dans les Réglages Système, puis placez
`~/Library/Input Methods/Plume-Francaise.app` dans la Corbeille.
Les substitutions personnelles se trouvent dans :

```text
~/Library/Application Support/PlumeFrancaise
```
