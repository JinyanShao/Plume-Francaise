# Historique des versions

Toutes les modifications importantes sont documentées dans ce fichier.

## Non publié

### Corrections

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
