# Format du tableau de commandes Excel

## Fichier : TABLEAU COMMANDE [MOIS].xlsx

Ce fichier est créé par les secrétaires chaque mois pour suivre toutes les commandes passées à ADITEC.

## Structure attendue (à adapter selon le fichier réel)

Le fichier contient un tableau avec les colonnes suivantes (les noms exacts peuvent varier) :

| Colonne probable | Description |
|-----------------|-------------|
| Chantier / Réf. | Nom du chantier (doit correspondre à "Réf. Commande" dans la facture) |
| Référence | Numéro de référence ADITEC ou désignation |
| Désignation | Nom du produit |
| Quantité | Quantité commandée |
| Unité | SAC, RLX, etc. |
| Gratuité / Dont gratuit | Quantité offerte par ADITEC (peut être vide = 0) |
| Date commande | Date de la commande |
| N° commande | Numéro de commande ADITEC |

## Lecture adaptative du fichier

Puisque le format peut évoluer, lire le fichier de façon adaptative :

```python
import pandas as pd

df = pd.read_excel(chemin_excel)

# Identifier les colonnes clés par mots-clés dans les noms de colonnes
col_chantier = [c for c in df.columns if any(kw in str(c).lower() 
                for kw in ['chantier', 'ref', 'réf', 'commande', 'client'])][0]

col_qte = [c for c in df.columns if any(kw in str(c).lower() 
           for kw in ['qte', 'quantité', 'quantite', 'qt'])][0]

col_gratuite = [c for c in df.columns if any(kw in str(c).lower() 
                for kw in ['gratuit', 'gratuité', 'offert', 'gratis'])][0] if any(
                any(kw in str(c).lower() for kw in ['gratuit', 'gratuité']) 
                for c in df.columns) else None
```

## Matching chantier facture ↔ tableau Excel

Le nom du chantier dans la facture (Réf. Commande) peut différer légèrement du nom dans le tableau Excel. Appliquer les règles de correspondance suivantes :

### Règles de matching :
1. **Correspondance exacte** (insensible à la casse) → utiliser directement
2. **Correspondance partielle** (l'un contient l'autre) → utiliser si unique
3. **Correspondance phonétique** (accents, caractères spéciaux) → normaliser et comparer
   - JOAO = João
   - FLEUR OCEAN = FLEUR OCÉAN
4. **Si aucune correspondance** → signaler à l'utilisatrice

```python
import unicodedata

def normalize_name(name):
    """Normalise un nom : minuscules, sans accents, sans espaces superflus"""
    if not name:
        return ""
    name = str(name).strip().lower()
    name = unicodedata.normalize('NFD', name)
    name = ''.join(c for c in name if unicodedata.category(c) != 'Mn')
    return name

def find_matching_chantier(chantier_facture, chantiers_excel):
    """Trouve le chantier Excel correspondant au chantier de la facture"""
    norm_fact = normalize_name(chantier_facture)
    
    # 1. Correspondance exacte
    for ch in chantiers_excel:
        if normalize_name(ch) == norm_fact:
            return ch
    
    # 2. Correspondance partielle
    matches = [ch for ch in chantiers_excel 
               if norm_fact in normalize_name(ch) or normalize_name(ch) in norm_fact]
    if len(matches) == 1:
        return matches[0]
    
    # 3. Aucune correspondance
    return None
```

## Gestion des gratuités — règle critique

La gratuité est la source d'erreur la plus fréquente identifiée par le client.

### Cas 1 : Gratuité respectée (cas normal)
- Commandé : 12 SAC dont 2 gratuités
- Attendu en facture : 10 SAC facturés (12 - 2)
- Si la facture montre 10 SAC → ✅ OK

### Cas 2 : Gratuité non respectée (erreur)
- Commandé : 12 SAC dont 2 gratuités
- Attendu en facture : 10 SAC facturés
- Si la facture montre 12 SAC → ⚠️ ERREUR — 2 SAC facturés à tort
- Impact : 2 × prix_unitaire = montant surfacturé

### Cas 3 : Gratuité facturée puis avoir
- La facture montre 12 SAC puis un avoir de -2 SAC sur un autre BL
- Total net = 10 SAC → ✅ OK (tenir compte de l'avoir)

### Cas 4 : Colonne gratuité vide
- Considérer comme 0 gratuité → Attendu = Commandé

## Gestion de la couleur dans le tableau Excel

**La comparaison des quantités se fait couleur par couleur.** Le tableau Excel doit donc avoir une colonne couleur, ou la couleur doit être intégrée dans la désignation ou dans une colonne séparée.

Lors de la lecture du tableau Excel, chercher une colonne "Couleur" ou extraire la couleur depuis la désignation du produit (ex: "MONODECOR GT B.00" → couleur "B.00").

Si le tableau Excel ne distingue pas les couleurs → signaler à l'utilisatrice et regrouper par référence uniquement pour cette analyse (dégrader gracieusement).

## Agrégation des quantités sur le mois

Un même chantier peut avoir plusieurs BL dans le mois. Agréger par **(chantier, référence, couleur)** :

```python
from collections import defaultdict

# Données facture agrégées — clé = (chantier, ref, couleur)
facture_agregee = defaultdict(float)
for bl in bons_livraison_facture:
    chantier = bl['chantier']
    for ligne in bl['lignes']:
        ref = ligne['ref_produit']
        couleur = ligne.get('couleur', '')
        qte = ligne['qte']
        # Les quantités négatives (avoirs) se soustraient du total
        facture_agregee[(chantier, ref, couleur)] += qte

# Comparaison avec le tableau Excel
for (chantier, ref, couleur), qte_facturee in facture_agregee.items():
    # Chercher dans le tableau Excel avec la même clé (chantier, ref, couleur)
    commande = tableau_excel.get((chantier, ref, couleur), {})
    
    if not commande:
        # Référence/couleur facturée mais pas dans le tableau → ALERTE JAUNE
        erreurs.append({"type": "SANS_COMMANDE", "chantier": chantier, 
                       "ref": ref, "couleur": couleur, ...})
        continue
    
    qte_commandee = commande.get('qte_commandee', 0)
    qte_gratuite = commande.get('qte_gratuite', 0) or 0
    qte_attendue = qte_commandee - qte_gratuite
    ecart = qte_facturee - qte_attendue
    
    if qte_gratuite > 0 and qte_facturee > qte_attendue:
        # ERREUR GRAVE : gratuité facturée
        impact = qte_gratuite * prix_ref
        erreurs.append({"type": "GRATUITÉ_FACTURÉE", "priorite": 1,
                       "chantier": chantier, "ref": ref, "couleur": couleur,
                       "qte_commandee": qte_commandee, "qte_gratuite": qte_gratuite,
                       "qte_attendue": qte_attendue, "qte_facturee": qte_facturee,
                       "impact_euros": impact, ...})
    elif ecart > 0:
        # ERREUR : trop facturé (sans gratuité)
        erreurs.append({"type": "ERREUR_QTE", "priorite": 2, ...})
    elif ecart < 0:
        # INFO : moins facturé que prévu
        infos.append({"type": "SOUS_FACTURATION", ...})
```
