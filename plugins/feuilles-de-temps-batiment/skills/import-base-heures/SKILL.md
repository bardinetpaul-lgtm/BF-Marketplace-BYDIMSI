---
name: import-base-heures
description: >
  Utiliser ce skill pour importer les données du fichier Excel dans la base de données SQLite,
  recueillir la note de qualité OCR, et gérer la boucle de correction. Se déclenche automatiquement
  après la génération du fichier Excel, ou quand l'utilisateur dit "importer en base",
  "enregistrer les heures", "sauvegarder dans la base", "mettre à jour la base",
  "j'ai corrigé le fichier Excel". Gère aussi les re-imports après correction manuelle.
metadata:
  version: "0.1.0"
  author: "DIMSI"
---

## Objectif

Importer toutes les données du fichier Excel dans la base SQLite centrale `heures_chantiers.db`, recueillir la note de qualité OCR donnée par l'utilisatrice, et gérer la boucle de correction si le résultat est insuffisant.

## Étape 1 — Localiser la base de données et le fichier Excel

**Base de données :** chercher `heures_chantiers.db` à la **racine du dossier "Feuilles de temps"**. Si elle n'existe pas, la créer automatiquement (script d'initialisation dans `references/sqlite-schema.md`).

**Fichier Excel :** chercher `Heures_[NomDuMois]_[Année].xlsx` dans le dossier du mois concerné. Si introuvable, demander à l'utilisatrice de l'indiquer.

## Étape 2 — Lire le fichier Excel

Utiliser `openpyxl` pour lire tous les onglets du fichier.

Pour chaque onglet (= chaque semaine) :
- Ignorer les lignes d'en-tête et les lignes vides
- Lire toutes les lignes de données (y compris les lignes "TOTAL SEMAINE")
- Détecter si une ligne a des erreurs (`⚠️ ÉCART` en colonne J ou confiance < 70% en colonne O)

## Étape 3 — Import avec écrasement (stratégie SUPPRIMER puis RÉINSÉRER)

Pour chaque combinaison `[annee + mois + num_semaine + nom_employe]` détectée dans le fichier Excel :

1. **Supprimer** toutes les lignes existantes dans la table `heures` avec ces mêmes valeurs
2. **Réinsérer** toutes les lignes du fichier Excel pour cette combinaison

Cela garantit que si la secrétaire a corrigé le fichier et relance l'import, les données sont proprement remplacées.

**Importer toutes les lignes**, y compris celles avec erreurs — elles sont flaggées via `a_des_erreurs = 1`.

Renseigner systématiquement :
- `date_import` = date et heure actuelle (format ISO : `YYYY-MM-DD HH:MM:SS`)
- `fichier_source` = nom du fichier Excel

Voir `references/sqlite-schema.md` pour le schéma complet et le script d'import.

## Étape 4 — Demander la note de qualité OCR

Après import, afficher à l'utilisatrice :

> "Le fichier a été importé ✅
> Sur 10, quelle note donnez-vous à la qualité de la lecture automatique des feuilles manuscrites ?"

Utiliser **AskUserQuestion** avec les boutons : `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`, `10`

Stocker la note dans la table `notes_qualite` (voir schéma).

## Étape 5 — Évaluation de la note et boucle de correction

### Note ≥ 7 — Succès
Afficher : "Parfait ! [N] ligne(s) importée(s) avec succès. Les heures de [Mois] [Année] sont enregistrées. 🎉"
Afficher le récapitulatif final (voir Étape 6).

### Note 5–6 — Résultat moyen
Afficher : "Résultat moyen noté. Avez-vous des corrections à apporter au fichier Excel avant de finaliser ?"

Utiliser **AskUserQuestion** :
- "Oui, j'ai corrigé le fichier Excel" → relancer depuis l'Étape 1 (re-import complet)
- "Non, c'est suffisant" → continuer vers l'Étape 6

### Note ≤ 4 — Résultat insuffisant
Afficher un message d'alerte clair :

> "⚠️ La qualité OCR est insuffisante (note [N]/10). Il est fortement recommandé de corriger le fichier Excel avant d'enregistrer définitivement les heures."

Utiliser **AskUserQuestion** :
- "J'ai corrigé le fichier Excel, relancer l'import" → relancer depuis l'Étape 1
- "Importer quand même (avec réserve)" → importer avec `necessite_verification = 1` pour toutes les lignes, puis Étape 6
- "Annuler l'import" → annuler, informer que rien n'a été enregistré

## Étape 6 — Récapitulatif final

Afficher un résumé lisible :

```
✅ Import terminé — [Mois] [Année]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👥 Employés traités : [N]
📅 Semaines : [liste]
📊 Lignes importées : [N]
⚠️  Lignes avec écart de total : [N]
🟡 Lignes à vérifier (confiance faible) : [N]
⭐ Note qualité OCR : [note]/10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Règles importantes

- Ne jamais faire d'import partiel : si une erreur survient, annuler et informer
- La note de qualité est toujours stockée, même en cas d'annulation de l'import (pour suivi statistique)
- Les lignes "TOTAL SEMAINE" du fichier Excel ne sont **pas** importées en base (elles sont recalculables)
- Utiliser uniquement du langage simple et rassurant — jamais de termes techniques pour l'utilisatrice
