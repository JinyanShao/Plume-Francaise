# Historique des versions

Toutes les modifications importantes sont documentées dans ce fichier.

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
