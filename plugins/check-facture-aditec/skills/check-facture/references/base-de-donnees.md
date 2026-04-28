# Base de données — 2 fichiers CSV

Deux fichiers CSV dans le dossier Cowork. C'est tout.

```
[dossier_projet]/
├── prix_aditec_produits.csv     ← référentiel de prix actuel
└── prix_aditec_historique.csv   ← historique des évolutions de prix
```

Les bons de livraison et les factures sont traités en mémoire pendant l'analyse — pas besoin de les persister.

---

## Fichier 1 : `prix_aditec_produits.csv`

**C'est la source de vérité absolue des prix.** Une ligne par (référence, couleur).

### Colonnes

| Colonne | Description | Exemple |
|---------|-------------|---------|
| `ref_produit` | Numéro de référence ADITEC | `18062` |
| `couleur` | Couleur si applicable, vide sinon | `B.00` ou `` |
| `designation` | Nom complet du produit | `MONODECOR GT P1 / 25 Kg` |
| `unite` | Unité de vente | `SAC` |
| `prix_ht` | Prix unitaire HT en euros | `6.24` |
| `date_maj` | Date de dernière mise à jour (YYYY-MM-DD) | `2026-02-13` |
| `source` | Origine du prix | `devis_PAREX2026` |

### Exemple de contenu

```
ref_produit,couleur,designation,unite,prix_ht,date_maj,source
18054,,PARMUREX / 25 Kg,SAC,5.12,2026-02-13,devis_PAREX2026
18062,,MONODECOR GT P1 / 25 Kg,SAC,6.24,2026-02-13,devis_PAREX2026
18062,B.00,MONODECOR GT P1 / 25 Kg,SAC,6.24,2026-03-05,facture_260006481
18062,J.10,MONODECOR GT P1 / 25 Kg,SAC,6.24,2026-01-31,facture_260001669
16099,,MONOBLANCO / 25 Kg,SAC,7.10,2026-02-13,devis_PAREX2026
9431,,PSE BD GRIS Th31 Ep.140 (2.16),M2,12.60,2026-02-13,devis_PAREX2026
9901426,,Eco-Contribution REP0.1426,PCE,0.14,2026-02-13,devis_PAREX2026
```

### Règle couleur

- **Depuis le devis** → 1 entrée par référence, couleur vide `""`
- **Depuis facture/BL** → 1 entrée par (référence + couleur) rencontrée
- Le prix est identique quelle que soit la couleur pour une même référence
- Pour chercher un prix : d'abord `(ref, couleur)`, si absent alors fallback sur `(ref, "")`

---

## Fichier 2 : `prix_aditec_historique.csv`

Trace chaque changement de prix pour suivre l'évolution dans le temps.

### Colonnes

| Colonne | Description | Exemple |
|---------|-------------|---------|
| `ref_produit` | Référence ADITEC | `18062` |
| `designation` | Nom du produit | `MONODECOR GT P1 / 25 Kg` |
| `ancien_prix` | Prix avant changement | `6.00` |
| `nouveau_prix` | Nouveau prix | `6.24` |
| `variation_pct` | Variation en % (arrondi 2 décimales) | `4.0` |
| `date_changement` | Date du changement (YYYY-MM-DD) | `2026-02-13` |
| `source` | Document source | `devis_PAREX2026` |

### Exemple de contenu

```
ref_produit,designation,ancien_prix,nouveau_prix,variation_pct,date_changement,source
18062,MONODECOR GT P1 / 25 Kg,6.00,6.24,4.0,2026-02-13,devis_PAREX2026
16099,MONOBLANCO / 25 Kg,7.33,7.10,-3.13,2026-02-13,devis_PAREX2026
```

---

## Fonctions Python à utiliser dans tous les skills

```python
import pandas as pd
from datetime import date
import os

COLS_PRODUITS   = ['ref_produit','couleur','designation','unite','prix_ht','date_maj','source']
COLS_HISTORIQUE = ['ref_produit','designation','ancien_prix','nouveau_prix','variation_pct','date_changement','source']

def lire_produits(dossier):
    chemin = os.path.join(dossier, "prix_aditec_produits.csv")
    if os.path.exists(chemin):
        return pd.read_csv(chemin, dtype=str)
    return pd.DataFrame(columns=COLS_PRODUITS)

def sauver_produits(df, dossier):
    chemin = os.path.join(dossier, "prix_aditec_produits.csv")
    df.to_csv(chemin, index=False, encoding='utf-8-sig')

def lire_historique(dossier):
    chemin = os.path.join(dossier, "prix_aditec_historique.csv")
    if os.path.exists(chemin):
        return pd.read_csv(chemin, dtype=str)
    return pd.DataFrame(columns=COLS_HISTORIQUE)

def sauver_historique(df, dossier):
    chemin = os.path.join(dossier, "prix_aditec_historique.csv")
    df.to_csv(chemin, index=False, encoding='utf-8-sig')

def trouver_prix(df_produits, ref, couleur=''):
    """Cherche le prix d'une référence. Fallback sur couleur vide si couleur spécifique absente."""
    masque = (df_produits['ref_produit'] == ref) & (df_produits['couleur'] == couleur)
    if not masque.any() and couleur != '':
        masque = (df_produits['ref_produit'] == ref) & (df_produits['couleur'] == '')
    if masque.any():
        row = df_produits[masque].iloc[0]
        return float(row['prix_ht']) if row['prix_ht'] != '' else None
    return None  # Référence inconnue

def maj_prix(df_produits, df_historique, ref, couleur, designation, unite, nouveau_prix, source):
    """Met à jour un prix. Retourne ('nouveau'|'hausse'|'baisse'|'inchange', ancien_prix, variation_pct)."""
    masque = (df_produits['ref_produit'] == ref) & (df_produits['couleur'] == couleur)
    aujourd_hui = date.today().isoformat()

    if masque.any():
        ancien_str = df_produits.loc[masque, 'prix_ht'].values[0]
        if ancien_str == '' or pd.isna(ancien_str):
            # Prix était inconnu, on le renseigne maintenant
            df_produits.loc[masque, 'prix_ht'] = nouveau_prix
            df_produits.loc[masque, 'date_maj'] = aujourd_hui
            df_produits.loc[masque, 'source'] = source
            return 'nouveau', None, None
        ancien_prix = float(ancien_str)
        if ancien_prix == nouveau_prix:
            return 'inchange', ancien_prix, 0.0
        # Prix a changé → enregistrer dans historique
        variation = round((nouveau_prix - ancien_prix) / ancien_prix * 100, 2)
        nouvelle_ligne_hist = pd.DataFrame([{
            'ref_produit': ref, 'designation': designation,
            'ancien_prix': ancien_prix, 'nouveau_prix': nouveau_prix,
            'variation_pct': variation, 'date_changement': aujourd_hui, 'source': source
        }])
        df_historique = pd.concat([df_historique, nouvelle_ligne_hist], ignore_index=True)
        df_produits.loc[masque, 'prix_ht'] = nouveau_prix
        df_produits.loc[masque, 'date_maj'] = aujourd_hui
        df_produits.loc[masque, 'source'] = source
        statut = 'hausse' if nouveau_prix > ancien_prix else 'baisse'
        return statut, ancien_prix, variation
    else:
        # Nouvelle référence
        nouvelle_ligne = pd.DataFrame([{
            'ref_produit': ref, 'couleur': couleur, 'designation': designation,
            'unite': unite, 'prix_ht': nouveau_prix,
            'date_maj': aujourd_hui, 'source': source
        }])
        df_produits = pd.concat([df_produits, nouvelle_ligne], ignore_index=True)
        return 'nouveau', None, None
```
