# Historique des versions

Toutes les modifications importantes sont documentées dans ce fichier.

## Non publié

### Ajouts

- Page de préférences entièrement en français (elle était passée en anglais lors d'un
  ajout précédent sans que le changement soit annoncé)
- La première fois que Plume Française est activée, la page de préférences s'ouvre
  automatiquement sur la section « Mode d'emploi », pour ne pas laisser l'utilisateur
  découvrir seul le fonctionnement des candidats ; cela ne se produit qu'une seule fois
- Réglages rapides directement dans le menu de saisie (« Valider le mot avec Espace » et
  un sous-menu « Genre ») pour changer ces deux préférences sans ouvrir la page de
  préférences ; les deux surfaces partagent le même réglage et restent synchronisées.
  Les intitulés du menu (« Préférences », « À propos ») sont passés en français au
  passage, pour rester cohérents avec le reste
- Apprentissage personnel : le mot effectivement validé pour une saisie donnée est retenu
  localement, et proposé en priorité la prochaine fois que la même saisie revient, sans
  rien à configurer (contrairement aux substitutions manuelles) ; un choix isolé ne suffit
  pas à l'apprendre, il faut qu'il se répète au moins une fois. Une substitution manuelle
  reste toujours prioritaire sur un choix appris. Section « Apprentissage personnel » dans
  la page de préférences pour tout réinitialiser
- Préférence « Grammaire » dans la page de préférences pour indiquer son propre genre
  (masculin, féminin ou non précisé) ; quand « je », « tu » ou « on » est le sujet d'un
  temps composé avec l'auxiliaire être, le participe proposé s'accorde désormais au
  féminin (`allée`, par exemple) si l'utilisateur l'a demandé — les temps simples et les
  temps composés avec avoir ne sont, eux, jamais concernés par l'accord
- Accord du participe passé avec un complément d'objet direct placé avant un temps composé
  avec avoir (« je l'ai vue », « je les ai vus ») ; comme l'élision de « le »/« la » en
  « l' » ne permet plus de deviner le genre de l'antécédent, les deux formes possibles sont
  proposées plutôt que d'en imposer une, de même pour le nombre avec « les » — un objet
  indirect comme « lui »/« leur » ne déclenche jamais cet accord

### Corrections

- Suppression de l'entrée de menu « Upgrade », restée sans aucune action associée
  depuis toujours (elle ne faisait rien au clic) ; la mise à jour se fait déjà via la
  page de préférences
- Un préfixe d'une ou deux lettres tapé après un contexte reconnu (par
  exemple `mo` après `je`) ne bascule plus directement sur la forme conjuguée
  du verbe le plus fréquent correspondant (`meurs`, pour `mourir`) ; les mots
  du dictionnaire classés par fréquence (`mon`…) restent prioritaires tant
  que le préfixe ne fait pas au moins trois lettres, comme pour `all` →
  `allons`
- Le candidat automatiquement mis en surbrillance à l'apparition de la liste
  ne remplace plus le texte souligné en cours de composition (par exemple
  `cont` affiché comme `continue`) tant que l'utilisateur n'a pas
  explicitement navigué avec les flèches ; le texte affiché correspond
  désormais à ce qui a été réellement tapé jusqu'à une sélection explicite
- Taper l'apostrophe (`'`) en cours de composition (par exemple `c` puis `'`)
  ne valide plus immédiatement `c'` en fermant la fenêtre de candidats ;
  l'apostrophe prolonge maintenant la composition comme une lettre normale,
  pour continuer à taper `c'est`, `c'était`… et valider soi-même avec
  Espace ou Retour
- Une fois l'apostrophe ainsi tapée à la main, l'élision correspondante
  (`c'est`, `l'homme`, `qu'il`, `d'accord`…) n'était plus reconnue comme un
  mot valide, faute d'ignorer cette apostrophe déjà présente dans la
  composition en cours ; elle est maintenant reconnue quel que soit le
  préfixe concerné
- Une élision techniquement possible mais rare (par exemple `m'o`, à partir
  du mot peu courant « o ») pouvait passer devant un mot du dictionnaire
  bien plus fréquent avec le même préfixe (`mon`) ; l'élision ne passe
  maintenant devant les correspondances du dictionnaire que si le mot dont
  elle dépend est effectivement le plus fréquent des deux
- Après avoir déjà tapé l'auxiliaire séparément (« je » puis « suis », par
  exemple), continuer avec le verbe (`all`) proposait le présent (`vais`)
  en tête plutôt que le participe attendu, et la forme composée du
  dictionnaire (`suis allé`) aurait de toute façon répété l'auxiliaire déjà
  présent dans le document ; le participe seul (`allé`) est maintenant
  proposé en premier dès que l'auxiliaire correspondant au sujet a déjà été
  tapé, pour être et avoir

## 1.1.0 — 3 septembre 2026

### Ajouts

- Bouton « Check for updates » dans la page de préférences (seule requête
  réseau de l’application, déclenchée uniquement sur clic)
- Section « How to use » dans la page de préférences

### Corrections

- Sélection d’un candidat par touche numérique (1-9) qui pouvait ne plus
  correspondre au candidat réellement affiché après une navigation aux
  flèches, une correction ou une sélection à la souris
- Le serveur de préférences local exigeait désormais un en-tête `Origin`
  correspondant pour toute requête qui modifie l’état, afin d’empêcher une
  page web tierce de le piloter à l’insu de l’utilisateur

## 1.0.0 — 28 juillet 2026

### Ajouts

- Complétion des accents français
- Apostrophe typographique et règles françaises d’espacement
- Classement par fréquence et prédiction selon le contexte
- 405 verbes fréquents au présent, passé composé, imparfait et futur simple
- Prise en charge de `être` et `avoir` au passé composé pour les verbes à double auxiliaire
- Priorité à `avoir` après un pronom complément d’objet direct comme `le`, `la` ou `les`
- Classement des conjugaisons selon le sujet précédent
- Fusion des corrections et conjugaisons équivalentes avec priorité aux formes verbales pertinentes
- Correction locale des accents manquants, inversions et fautes courantes
- Compatibilité Universal avec Apple Silicon et Intel
- Page de préférences entièrement en français

### Confidentialité

- Traitement des candidats et du contexte exclusivement sur le Mac
- Suppression des anciens dictionnaires chinois et anglais
- Suppression des fonctions de traduction et de la configuration autorisant les
  connexions réseau arbitraires

### Corrections

- Conservation du texte lors de la saisie d’une apostrophe gauche
- Normalisation de `'`, `‘` et `’` vers l’apostrophe typographique française
- Conservation des contextes élidés comme `j’`, `n’` et `qu’il` pour le classement des conjugaisons
- Priorité aux graphies françaises exactes comme `ça` avant les élisions hypothétiques
- Enregistrement fiable de la méthode de saisie dans macOS
