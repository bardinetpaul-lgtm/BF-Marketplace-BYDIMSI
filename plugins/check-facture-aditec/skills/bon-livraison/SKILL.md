---
name: bon-livraison
description: >
  Ce skill analyse un bon de livraison ADITEC, vérifie les prix par rapport au référentiel,
  et enregistre chaque ligne (référence + couleur + prix) dans la base. Il se déclenche quand
  l'utilisatrice choisit "Vérifier un bon de livraison" dans le menu principal, ou dit
  "j'ai un bon de livraison", "vérifier le BL", "contrôler la livraison".
metadata:
  version: "0.1.0"
---

## Objectif

Pour chaque ligne d'un bon de livraison ADITEC :
- Comparer le prix facturé avec le référentiel de prix
- **Alerter si un prix est supérieur au référentiel** (erreur grave)
- **Mettre à jour silencieusement si un prix est inférieur** (favorable, juste informer)
- **Créer la référence dans la base si elle est inconnue** (avec son prix et sa couleur)
- Enregistrer le BL complet dans la table `bons_livraison` et `bons_livraison_lignes`

## Étape 1 — Demande du bon de livraison

Afficher ce message et **s'arrêter** :

> "Pour vérifier un bon de livraison, déposez le PDF directement dans la conversation, puis envoyez votre message."

Ne pas utiliser AskUserQuestion. Ne pas continuer avant d'avoir reçu le fichier PDF dans la conversation.

## Étape 2 — Vérification de la base de prix

Vérifier que `prix_aditec_produits.csv` existe dans le dossier Cowork.
- Si il n'existe pas → le créer vide (avec les en-têtes) et informer l'utilisatrice :
  > "Votre base de prix n'existe pas encore. Je vais la créer maintenant et y enregistrer ce bon de livraison."
- Si il existe → procéder normalement

## Étape 3 — Extraction du bon de livraison

### Ce que contient un BL ADITEC :
- En-tête : N° BL, Date, N° Commande, Réf. Commande (= chantier), Notre Référence (= lieu)
- Client livré (ex: BARROS FACADES, BREIZH IMMO...)
- Tableau : Désignation | N° produit | Quantité | Unité
- **Attention : les BL ADITEC n'affichent PAS les prix** — seule la facture mensuelle contient les prix

### Pour chaque ligne du BL, extraire :
- `ref_produit` : numéro de référence ADITEC
- `designation` : nom complet du produit
- `quantite` : quantité livrée (peut être négative pour un avoir)
- `unite` : SAC, RLX, PCE, ML, M², SEA, BID, BTE, BD...
- `couleur` : valeur sur la ligne "Couleur: X.XX" juste en dessous de la désignation (ex: "B.00", "J.10"). Chaîne vide `""` si pas de couleur.

### Lignes à ignorer :
- FRAIS DE DECHARGEMENT (ref 7410) — frais de transport, pas un produit
- TRANSPORT FOURGON (ref 14906) — frais de transport
- Lignes sans numéro de produit

### Exemple d'extraction du BL 1183318 :
```
Chantier: BREIZH IMMO — Lieu: GUENIN — Lorient
- 14906 : TRANSPORT FOURGON, 1,00 PCE → IGNORER
- 18062 : MONODECOR GT P1 / 25 Kg, 16,00 SAC, couleur "" (pas de couleur mentionnée dans cet exemple)
```

## Étape 4 — Comparaison et mise à jour de la base

**Note : Les BL ADITEC ne contiennent pas de prix.** La comparaison de prix se fait uniquement lors de l'analyse de la facture mensuelle (skill `analyse-facture`).

Pour chaque ligne du BL :

### 4.1 — Chercher dans le CSV produits

```python
import pandas as pd, os
from datetime import date

DOSSIER = "[DOSSIER_COWORK]"
df_produits = pd.read_csv(os.path.join(DOSSIER, "prix_aditec_produits.csv"), dtype=str) \
    if os.path.exists(os.path.join(DOSSIER, "prix_aditec_produits.csv")) \
    else pd.DataFrame(columns=['ref_produit','couleur','designation','unite','prix_ht','date_maj','source'])

# Chercher (ref, couleur) puis fallback sur (ref, couleur vide)
masque = (df_produits['ref_produit'] == ref) & (df_produits['couleur'] == couleur)
if not masque.any():
    masque = (df_produits['ref_produit'] == ref) & (df_produits['couleur'] == '')
connu = masque.any()
```

### 4.2 — Si la référence+couleur est inconnue
→ Ajouter dans `prix_aditec_produits.csv` avec `prix_ht` vide (sera renseigné à la première facture) :
```python
nouvelle_ligne = {
    'ref_produit': ref, 'couleur': couleur, 'designation': designation,
    'unite': unite, 'prix_ht': '',
    'date_maj': date.today().isoformat(), 'source': f'bon_livraison_{num_bl}'
}
df_produits = pd.concat([df_produits, pd.DataFrame([nouvelle_ligne])], ignore_index=True)
df_produits.to_csv(os.path.join(DOSSIER, "prix_aditec_produits.csv"), index=False, encoding='utf-8-sig')
```
Marquer dans le rapport : **"Nouveau produit détecté — prix à confirmer sur la prochaine facture"**

### 4.3 — Si la référence+couleur est connue
→ Confirmer simplement qu'elle est dans le CSV. Aucune modification.

### 4.4 — Sauvegarder les CSV

Après traitement, sauvegarder uniquement les deux fichiers qui ont pu être modifiés :
```python
sauver_produits(df_produits, DOSSIER)
sauver_historique(df_historique, DOSSIER)
```

Les détails du BL (quelles lignes, quel chantier...) sont traités en mémoire uniquement. Pas besoin de les persister.

## Étape 5 — Rapport à l'utilisatrice

Présenter un résumé clair :

```
✅ Bon de livraison N° [NUM_BL] enregistré !

📦 Chantier : [NOM_CHANTIER]
📍 Lieu : [LIEU]
📅 Date : [DATE]

✅ Références connues dans votre base : X produits
🆕 Nouvelles références ajoutées (prix à confirmer) :
  - MONODECOR GT P1 Couleur G.00 (18062 / G.00) — prix inconnu, sera vérifié sur la prochaine facture

Les prix de ce bon de livraison seront vérifiés lors de l'analyse de la facture du mois.
```

Si c'est un avoir (quantités négatives) :
```
ℹ️ Ce bon de livraison est un AVOIR (retour de marchandise).
Les quantités négatives ont bien été enregistrées.
```

## Note sur la vérification des prix

Les prix apparaissent sur la **facture mensuelle**, pas sur les bons de livraison individuels.
C'est le skill `analyse-facture` qui effectue la vérification des prix ligne par ligne.
Le rôle du skill BL est d'enrichir la base avec les nouvelles références rencontrées avant l'analyse mensuelle.
