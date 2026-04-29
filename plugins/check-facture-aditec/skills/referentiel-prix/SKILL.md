---
name: referentiel-prix
description: >
  Ce skill gère la mise à jour du référentiel de prix à partir d'un devis ADITEC (Remise de Prix).
  Il se déclenche quand l'utilisatrice choisit "Mettre à jour le référentiel de prix" dans le menu
  principal, ou dit "j'ai reçu un nouveau devis", "mettre à jour les prix", "nouveau tarif ADITEC".
metadata:
  version: "0.1.0"
---

## Objectif

Extraire toutes les références et leurs prix d'un devis ADITEC (document "REMISE DE PRIX"), les comparer avec la base de prix existante, mettre à jour la base, et notifier l'utilisatrice des changements importants.

## Étape 1 — Demande du fichier

Afficher ce message et **s'arrêter** :

> "Pour mettre à jour vos prix, déposez le fichier du devis ADITEC (Remise de Prix) directement dans la conversation, puis envoyez votre message."

Ne pas utiliser AskUserQuestion. Ne pas continuer avant d'avoir reçu le fichier PDF dans la conversation.

## Étape 2 — Extraction des données du devis

Analyse le PDF du devis ADITEC. Pour chaque ligne de produit, extraire :
- **N° produit** (référence numérique, ex: 18062)
- **Désignation** (nom complet du produit, ex: "MONODECOR GT P1 / 25 Kg")
- **Quantité de référence** (quantité du devis, pour info)
- **Unité** (SAC, RLX, PCE, ML, M², SEA, BID, BTE, BD...)
- **Prix HT unitaire** (prix à l'unité, ex: 6,24 €)

**Règles d'extraction importantes :**
- Ignorer les lignes de total de section ("Total 1. SOUS ENDUIT" etc.)
- Ignorer les lignes sans numéro de produit
- Les éco-contributions (références commençant par 990...) SONT à inclure dans la base
- Le prix dans le devis est le prix UNITAIRE (à l'unité SAC, RLX, etc.), pas le prix total
- Les sous-catégories (1. SOUS ENDUIT, 2. ENDUIT LOURD...) sont informatives, les ignorer pour la base
- La couleur (Couleur: B.00) est une info complémentaire, ne pas l'intégrer dans la référence

Consulte `references/extraction-devis.md` pour les règles détaillées d'analyse du format ADITEC.

## Étape 3 — Comparaison avec la base existante

Lire `prix_aditec_produits.csv` depuis le dossier Cowork (voir format dans check-facture/references/base-de-donnees.md).
Si le fichier n'existe pas → le créer vide avec les bonnes colonnes.

Pour chaque produit extrait du devis :
1. Chercher `(ref_produit, couleur='')` dans le CSV — les entrées du devis ont toujours la couleur vide
2. **Si la référence n'existe pas** → Ajouter une nouvelle ligne dans le CSV
3. **Si le prix est identique** → Aucun changement
4. **Si le prix a augmenté** → Mettre à jour le CSV + ajouter une ligne dans `prix_aditec_historique.csv` + NOTER l'alerte
5. **Si le prix a baissé** → Mettre à jour le CSV + ajouter une ligne dans `prix_aditec_historique.csv` + NOTER l'info

## Étape 4 — Mise à jour des fichiers CSV

Utiliser Python avec pandas. Lire → modifier → réécrire le fichier complet.

```python
import pandas as pd
from datetime import date
import os

DOSSIER = "[DOSSIER_COWORK]"
FICHIER_PRODUITS = os.path.join(DOSSIER, "prix_aditec_produits.csv")
FICHIER_HISTORIQUE = os.path.join(DOSSIER, "prix_aditec_historique.csv")

COLS_PRODUITS = ['ref_produit','couleur','designation','unite','prix_ht','date_maj','source']
COLS_HISTORIQUE = ['ref_produit','designation','ancien_prix','nouveau_prix','variation_pct','date_changement','source']

# Lire ou créer
if os.path.exists(FICHIER_PRODUITS):
    df = pd.read_csv(FICHIER_PRODUITS, dtype=str)
else:
    df = pd.DataFrame(columns=COLS_PRODUITS)

# Pour chaque produit du devis :
# masque = (df['ref_produit'] == ref) & (df['couleur'] == '')
# ... modifier df ...

# Réécrire
df.to_csv(FICHIER_PRODUITS, index=False, encoding='utf-8-sig')
```

## Étape 5 — Rapport à l'utilisatrice

Présenter un résumé clair en langage naturel :

```
✅ Référentiel mis à jour avec succès !

📊 Résumé :
- X nouveaux produits ajoutés
- X produits mis à jour (prix inchangé)
- X produits avec un nouveau prix

⬆️ HAUSSES DE PRIX (à surveiller) :
- MONODECOR GT P1 (18062) : 6,00 € → 6,24 € (+4%)
- ...

⬇️ Baisses de prix (favorable) :
- PARMUREX (18054) : 5,50 € → 5,12 € (-7%)
- ...

🆕 Nouveaux produits ajoutés :
- BELLE EPOQUE GRAIN FIN (4987) : 9,21 €/SAC
- ...
```

Si des hausses de prix significatives (>5%) sont détectées, le signaler clairement.

## Gestion des erreurs

- Si le PDF n'est pas un devis ADITEC reconnu → expliquer simplement ce qui ne va pas
- Si une référence a un format inhabituel → la noter dans le rapport mais continuer
- Si la base est corrompue → prévenir l'utilisatrice et proposer de recréer la base
