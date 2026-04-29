---
name: selection-du-mois
description: >
  Utiliser ce skill quand l'utilisateur veut traiter des feuilles de temps, lancer le traitement
  des heures du mois, sélectionner un mois à traiter, ou quand l'utilisateur dit "je veux traiter
  les feuilles", "on va traiter le mois de [mois]", "lance le traitement", "feuilles de temps",
  "j'ai les scans", "voilà les PDFs du mois". Ce skill est le point d'entrée principal du plugin.
metadata:
  version: "0.1.0"
  author: "DIMSI"
---

## Objectif

Point d'entrée du traitement. Explorer l'arborescence du dossier "Feuilles de temps" dans le projet et guider l'utilisateur pour sélectionner le mois à traiter, avec une interface claire à base de boutons.

## Étape 1 — Localiser le dossier "Feuilles de temps"

Chercher dans le dossier de travail (workspace) un dossier nommé **"Feuilles de temps"** (respecter exactement la casse et les espaces).

Si ce dossier n'existe pas :
- Afficher un message clair et bienveillant : "Je n'ai pas trouvé le dossier 'Feuilles de temps' dans votre espace de travail. Merci de le créer avec l'arborescence suivante :"
- Afficher l'arborescence attendue (voir ci-dessous)
- Arrêter le traitement

**Arborescence attendue :**
```
Feuilles de temps/
└── 2026/
    ├── 01 - Janvier/
    │   ├── Semaine 01/
    │   │   ├── dupont.pdf
    │   │   └── martin.pdf
    │   └── Semaine 02/
    │       └── ...
    └── 03 - Mars/
        ├── Semaine 13/
        │   ├── stephan.pdf
        │   ├── rui.pdf
        │   └── thomas.pdf
        └── Semaine 14/
            └── ...
```

## Étape 2 — Scanner l'arborescence complète

Parcourir récursivement le dossier "Feuilles de temps" pour construire la liste de tous les dossiers mois existants.

Format attendu :
- Dossiers année : `YYYY` (ex : `2026`)
- Dossiers mois : `MM - NomDuMois` (ex : `03 - Mars`, `11 - Novembre`)
- Dossiers semaine (dans chaque mois) : `Semaine XX` (ex : `Semaine 13`, `Semaine 04`)
- Fichiers PDF : directement dans le dossier semaine

Construire une liste des mois disponibles : `[Année] — [NomDuMois]` (ex : `2026 — Mars`).

Si aucun dossier mois n'est trouvé : informer l'utilisateur et arrêter.

## Étape 3 — Demander le mois à traiter

Utiliser **AskUserQuestion** avec :
- Message : "Quel mois souhaitez-vous traiter ?"
- Options : chaque mois disponible sous forme de bouton (format `[Année] — [NomDuMois]`)
- Trier par ordre chronologique (plus récent en premier)

## Étape 4 — Scanner le dossier du mois sélectionné

Lister tous les sous-dossiers `Semaine XX` dans le dossier du mois choisi.
Pour chaque dossier semaine, lister les fichiers `.pdf` qu'il contient (insensible à la casse).

Si aucun dossier semaine ou aucun PDF : afficher "Aucune feuille de temps trouvée pour ce mois. Merci de créer les dossiers de semaine et d'y déposer les scans PDF avant de relancer."

Afficher un récapitulatif avant de continuer :
- ✅ Mois sélectionné : [Année] — [Mois]
- 📅 [N] semaine(s) trouvée(s)
- 📄 [N] feuille(s) au total — avec le détail par semaine : "Semaine 13 : stephan.pdf, rui.pdf, thomas.pdf"

## Étape 5 — Demander confirmation et lancer l'OCR

Utiliser **AskUserQuestion** pour confirmer :
- Message : "Voulez-vous lancer le traitement OCR de ces [N] feuilles ?"
- Options : "Oui, lancer le traitement" / "Non, annuler"

Si confirmation : passer au skill **ocr-feuilles-de-temps** la structure complète : chemin du dossier mois, liste des semaines avec pour chacune son numéro et la liste de ses PDFs.

Si annulation : afficher "Traitement annulé. Revenez quand vous êtes prête !" et s'arrêter.

## Règles importantes

- Ne jamais exposer de chemins techniques internes à l'utilisateur
- Utiliser un langage simple et bienveillant — l'utilisatrice n'est pas technicienne
- En cas de doute sur un dossier mal nommé, signaler sans bloquer (proposer quand même les dossiers reconnus)
