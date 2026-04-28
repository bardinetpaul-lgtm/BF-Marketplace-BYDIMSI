# Plugin Check Facture ADITEC

## Vue d'ensemble

Ce plugin permet aux secrétaires de **Barros Facades** de vérifier automatiquement les factures reçues d'ADITEC. Il compare les quantités facturées avec les commandes passées, et les prix facturés avec le référentiel de prix négocié.

## Utilisation

Taper `/CheckFacture` dans la conversation pour lancer le workflow. Le plugin guide l'utilisatrice étape par étape.

## Ce que fait le plugin

### 1. Mise à jour du référentiel de prix
Quand ADITEC envoie un nouveau devis (Remise de Prix), le plugin extrait automatiquement tous les prix et met à jour la base interne. Il signale les hausses et baisses de prix.

### 2. Vérification d'un bon de livraison
Pour chaque bon de livraison reçu, le plugin vérifie que les références sont connues dans la base de prix. Il ajoute automatiquement les nouvelles références.

### 3. Analyse de la facture du mois
C'est la fonction principale. Le plugin :
- Compare les quantités facturées avec le tableau de commandes Excel (chantier par chantier)
- Détecte les gratuités facturées à tort
- Compare les prix avec le référentiel
- Génère un fichier Excel coloré avec toutes les erreurs

## Base de données

Le plugin utilise **2 fichiers CSV** dans le dossier Cowork sélectionné. Pas de base de données complexe — des fichiers texte simples, robustes, et consultables directement dans Excel :

| Fichier | Contenu |
|---------|---------|
| `prix_aditec_produits.csv` | Référentiel de prix actuel (une ligne par référence + couleur) |
| `prix_aditec_historique.csv` | Historique des évolutions de prix |

## Skills inclus

| Skill | Déclencheur | Description |
|-------|-------------|-------------|
| `check-facture` | `/CheckFacture` | Point d'entrée principal — menu de navigation |
| `referentiel-prix` | Via menu | Mise à jour des prix depuis un devis ADITEC |
| `bon-livraison` | Via menu | Vérification d'un bon de livraison |
| `analyse-facture` | Via menu | Analyse complète facture vs commandes |

## Fichiers attendus

| Fichier | Format | Description |
|---------|--------|-------------|
| Remise de Prix ADITEC | PDF | Devis annuel avec les prix négociés |
| Bon de livraison | PDF | BL ADITEC reçu à la livraison |
| Facture ADITEC | PDF | Facture mensuelle récapitulative |
| Tableau commandes | .xlsx | Tableau Excel mensuel des commandes |

## Fichiers générés

| Fichier | Description |
|---------|-------------|
| `prix_aditec_produits.csv` | Référentiel de prix (créé automatiquement) |
| `prix_aditec_historique.csv` | Historique des prix (créé automatiquement) |
| `RAPPORT_FACTURE_[MOIS]_[ANNEE].xlsx` | Rapport d'analyse mensuel |

## Prérequis

- Python avec les bibliothèques : `pandas`, `openpyxl`
- Le dossier Cowork doit être sélectionné avant de commencer

## Notes importantes

- Les **frais de gestion** (réf. 18016) et la **participation indexation gasoil** (réf. 19440) sont ignorés
- Les **quantités négatives** dans la facture sont des avoirs et sont correctement prises en compte
- La **tolérance de prix est zéro** : tout écart, même de 0,01 €, est signalé
- Les **éco-contributions** sont incluses dans l'analyse des prix
