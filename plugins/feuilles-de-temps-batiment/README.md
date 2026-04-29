# Plugin — Feuilles de temps Bâtiment

Traitement automatisé des feuilles de temps manuscrites pour entreprises du bâtiment.

## Ce que fait ce plugin

1. **Sélection du mois** — Parcourt le dossier "Feuilles de temps" et propose un choix de mois via une interface à boutons, sans manipulation technique.
2. **OCR → Excel** — Lit les PDFs manuscrits, extrait toutes les données (heures, chantiers, villes), génère un fichier Excel structuré avec scores de confiance et détection automatique des écarts.
3. **Import en base** — Importe les données validées dans une base SQLite locale, gère les doublons, et stocke les notes de qualité OCR pour suivi.

## Structure attendue dans le projet

```
Feuilles de temps/
├── heures_chantiers.db       ← base de données (créée automatiquement)
├── 2025/
│   └── 01 - Janvier/
│       ├── Semaine 01/
│       │   ├── dupont.pdf
│       │   └── martin.pdf
│       └── Semaine 02/
│           └── ...
└── 2026/
    └── 03 - Mars/
        ├── Semaine 13/
        │   ├── stephan.pdf
        │   ├── rui.pdf
        │   └── thomas.pdf
        ├── Semaine 14/
        │   └── kevin.pdf
        └── Heures_Mars_2026.xlsx  ← généré automatiquement par le plugin
```

## Skills disponibles

| Skill | Déclencheur | Rôle |
|-------|-------------|------|
| `selection-du-mois` | "je veux traiter les feuilles", "feuilles de temps" | Point d'entrée : choisir le mois |
| `ocr-feuilles-de-temps` | Automatique après sélection, ou "fais l'OCR" | Lire les PDFs → Excel |
| `import-base-heures` | Automatique après Excel, ou "importer en base" | Excel → SQLite + notation |

## Format du fichier Excel produit

- 1 onglet par semaine (ex : "Semaine 13")
- 18 colonnes : heures, chantier, ville, montage/démontage, score de confiance OCR, commentaires
- Surlignage orange = écart entre total manuscrit et total calculé
- Surlignage jaune = valeur peu lisible à vérifier

## Base de données SQLite

Fichier : `Feuilles de temps/heures_chantiers.db`

Tables :
- `heures` — toutes les lignes de travail importées
- `notes_qualite` — notes de qualité OCR données par la secrétaire

Chaque re-traitement d'un mois **écrase** les données existantes pour ce mois (propre et sans doublons).

## Prérequis techniques

Python avec les packages :
- `openpyxl` — manipulation Excel
- `sqlite3` — inclus dans Python standard
