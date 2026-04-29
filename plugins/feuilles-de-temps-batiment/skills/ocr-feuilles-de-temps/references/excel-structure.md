# Structure du fichier Excel — Feuilles de temps

## Organisation des onglets

- 1 onglet par numéro de semaine : `Semaine 13`, `Semaine 14`, etc.
- Dans chaque onglet : tous les employés de la semaine, l'un sous l'autre, séparés par une ligne vide

## Colonnes — 16 colonnes exactement (pas plus, pas moins)

| Col | Lettre | Intitulé | Notes |
|-----|--------|----------|-------|
| 1  | A | N° Sem | Numéro de semaine |
| 2  | B | Nom Employé | |
| 3  | C | Jour | Lundi / Mardi / Mercredi / Jeudi / Vendredi |
| 4  | D | Mat. Début | HH:MM |
| 5  | E | Mat. Fin | HH:MM |
| 6  | F | AM Début | HH:MM |
| 7  | G | AM Fin | HH:MM |
| 8  | H | Total (OCR) | Valeur lue sur la feuille |
| 9  | I | Total (Calc.) | Calculé automatiquement |
| 10 | J | Écart | "OK" ou "⚠️ ÉCART" |
| 11 | K | Nom Chantier | |
| 12 | L | Ville | |
| 13 | M | Montage | "Oui" / "Non" |
| 14 | N | Démontage | "Oui" / "Non" |
| 15 | O | Confiance % | Score OCR 0-100 |
| 16 | P | Commentaire OCR | Note OCR si incertitude |

⛔ Il n'y a PAS de colonnes "Du" et "Au". 16 colonnes seulement.

## Mise en forme

- **Orange** → uniquement la cellule J (Écart) quand valeur = "⚠️ ÉCART"
- **Jaune** → uniquement la cellule P (Commentaire OCR) quand confiance < 70%
- **Bleu pâle** → ligne TOTAL SEMAINE complète
- **Gris très léger / blanc** → alternance entre blocs d'employés
- Aucune ligne entière ne doit être colorée en orange ou jaune
