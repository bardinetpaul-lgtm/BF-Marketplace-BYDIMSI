# Structure des fichiers CSV — Feuilles de temps

## Fichier `heures.csv`

Situé à la racine du dossier "Feuilles de temps". Contient toutes les lignes d'heures travaillées.

| Colonne | Description |
|---------|-------------|
| annee | Année (ex: 2026) |
| mois | Numéro du mois (ex: 3) |
| num_semaine | Numéro de semaine (ex: 13) |
| nom_employe | Nom tel que lu sur la feuille |
| jour | Lundi / Mardi / Mercredi / Jeudi / Vendredi |
| matin_debut | Heure début matin (HH:MM) |
| matin_fin | Heure fin matin (HH:MM) |
| apm_debut | Heure début après-midi (HH:MM) |
| apm_fin | Heure fin après-midi (HH:MM) |
| total_ocr | Total lu sur la feuille (ex: 9h00) |
| total_calcule | Total calculé automatiquement (ex: 9h00) |
| ecart | 1 si écart > 5 min, 0 sinon |
| nom_chantier | Nom du chantier |
| ville | Ville du chantier |
| montage | 1 = Oui, 0 = Non |
| demontage | 1 = Oui, 0 = Non |
| confiance_pct | Score de confiance OCR (0-100) |
| commentaire_ocr | Note OCR si valeur incertaine |
| a_des_erreurs | 1 si écart ou confiance < 70, sinon 0 |
| date_import | Date et heure de l'enregistrement |
| fichier_source | Nom du fichier PDF source |

## Fichier `notes_qualite.csv`

Situé à la racine du dossier "Feuilles de temps". Contient une ligne par traitement mensuel.

| Colonne | Description |
|---------|-------------|
| annee | Année |
| mois | Numéro du mois |
| nom_fichier | Nom du fichier Excel généré |
| note | Note de qualité OCR (1-10) |
| date_note | Date et heure de la notation |

## Stratégie de mise à jour

À chaque re-traitement d'un mois, toutes les lignes existantes pour ce mois sont supprimées et remplacées. Cela garantit des données propres sans doublons.
