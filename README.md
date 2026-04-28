# DIMSI Plugins Marketplace

Marketplace Claude Code regroupant les plugins métier de DIMSI.

## Plugins disponibles

### 📋 feuilles-de-temps-batiment
Traitement automatisé des feuilles de temps manuscrites pour les entreprises du bâtiment.
- OCR des PDFs scannés
- Génération de fichier Excel avec scores de confiance
- Import dans une base SQLite des heures chantiers

### 🧾 check-facture-aditec
Vérification des factures et bons de livraison ADITEC.
- Contrôle des quantités vs commandes
- Contrôle des prix vs référentiel
- Mise à jour du référentiel depuis devis (Remise de Prix)

## Installation

Dans Claude Code (CLI) ou Cowork :

```
/plugin marketplace add bardinetpaul-lgtm/dimsi-plugins
/plugin install feuilles-de-temps-batiment@dimsi-plugins
/plugin install check-facture-aditec@dimsi-plugins
```

## Mise à jour

Pour récupérer la dernière version après un push sur ce repo :

```
/plugin marketplace update dimsi-plugins
/plugin update feuilles-de-temps-batiment@dimsi-plugins
/plugin update check-facture-aditec@dimsi-plugins
```

## Structure du repo

```
dimsi-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Manifest marketplace
└── plugins/
    ├── feuilles-de-temps-batiment/
    │   ├── .claude-plugin/plugin.json
    │   └── skills/
    └── check-facture-aditec/
        ├── .claude-plugin/plugin.json
        └── skills/
```

## Pour le mainteneur (Paul / DIMSI)

Pour ajouter un nouveau plugin :
1. Créer un dossier `plugins/<nom-du-plugin>/`
2. Y mettre `.claude-plugin/plugin.json` + `skills/`
3. Ajouter une entrée dans `.claude-plugin/marketplace.json`
4. Bumper la `version` du plugin modifié
5. `git commit && git push`

## Auteur

DIMSI – p.bardinet@dimsi.fr
