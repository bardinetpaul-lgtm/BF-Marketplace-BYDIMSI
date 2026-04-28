# Format du rapport Excel d'analyse de facture

## Fichier : `RAPPORT_FACTURE_ADITEC.xlsx`

**Nom fixe, toujours le même.** Le fichier est écrasé à chaque analyse — pas de doublons, pas de confusion.

Utiliser openpyxl pour créer le fichier avec mise en forme.

```python
from openpyxl import Workbook
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import os

wb = Workbook()
```

## Feuille 1 : "Résumé"

Contient un tableau de synthèse des erreurs triées par gravité.

### Colonnes :
| Col | Nom | Largeur | Format |
|-----|-----|---------|--------|
| A | Type d'erreur | 25 | Texte |
| B | Chantier | 20 | Texte |
| C | N° BL | 15 | Texte |
| D | Référence produit | 15 | Texte |
| E | Désignation | 35 | Texte |
| F | Quantité commandée | 20 | Nombre |
| G | Gratuité | 12 | Nombre |
| H | Quantité attendue | 20 | Nombre |
| I | Quantité facturée | 20 | Nombre |
| J | Écart quantité | 15 | Nombre (rouge si >0) |
| K | Prix référentiel | 18 | Monétaire |
| L | Prix facturé | 15 | Monétaire |
| M | Écart prix unitaire | 18 | Monétaire (rouge si >0) |
| N | Impact financier | 18 | Monétaire (rouge si >0) |
| O | Statut | 15 | Texte |

### Codes couleur des lignes :
- 🔴 Rouge vif (#FF0000) : **Erreur grave** — gratuité facturée à tort OU surfacturation en quantité ET en prix
- 🟠 Orange (#FF8C00) : **Erreur** — surfacturation de prix (prix facturé > prix référentiel) OU quantité facturée > quantité commandée (sans gratuité en cause)
- 🟡 Jaune (#FFD700) : **À vérifier** — référence inconnue dans la base, facturée sans commande correspondante
- 🟢 Vert (#90EE90) : **Information positive** — prix à la baisse (mis à jour), nouveau produit ajouté
- ⚪ Blanc : Ligne OK (si mode détaillé)

**Règle absolue sur les gratuités :** Une gratuité facturée est TOUJOURS une erreur grave (rouge vif), quel que soit le montant. C'est la priorité n°1 de détection.

### En-tête :
- Ligne 1 : Titre "RAPPORT D'ANALYSE FACTURE ADITEC — [MOIS] [ANNÉE]" en gras, fond bleu marine (#003366), texte blanc
- Ligne 2 : Date d'analyse, N° facture analysée
- Ligne 3 : Vide (séparation)
- Ligne 4 : En-têtes des colonnes en gras, fond gris clair (#E0E0E0)
- Ligne 5+ : Données

### Ligne de totaux en bas :
- Total erreurs quantité : X SAC / BTE / ... en trop
- Impact financier total : X,XX €
- Total erreurs prix : X lignes
- Impact financier prix total : X,XX €

## Feuille 2 : "Détail par chantier"

Un tableau par chantier, avec toutes les lignes de la facture pour ce chantier.

### Structure pour chaque chantier :
```
[CHANTIER : KEVIN]                     [LIEU : LORIENT]
Référence | Désignation | Commandé | Gratuit | Attendu | Facturé | Écart | Prix Ref | Prix Fact | Écart Prix | Impact | Statut
18062     | MONODECOR.. | 4        | 0       | 4       | 5       | +1   | 6,24     | 6,24      | 0,00      | 0,00€  | ⚠️ QTE
...
[Sous-total chantier KEVIN]
```

## Feuille 3 : "Gratuités non respectées"

Feuille dédiée uniquement aux cas où une gratuité a quand même été facturée — cas le plus fréquent d'erreur selon le client.

Colonnes : Chantier | Référence | Désignation | Qté gratuite commandée | Qté facturée | Impact €

## Code Python pour créer le rapport

```python
from openpyxl import Workbook
from openpyxl.styles import PatternFill, Font, Alignment
from openpyxl.utils import get_column_letter

def create_rapport(erreurs, mois, annee, output_path):
    wb = Workbook()
    
    # ---- Feuille Résumé ----
    ws = wb.active
    ws.title = "Résumé"
    
    # Titre
    ws.merge_cells('A1:O1')
    titre = ws['A1']
    titre.value = f"RAPPORT D'ANALYSE FACTURE ADITEC — {mois.upper()} {annee}"
    titre.font = Font(bold=True, color="FFFFFF", size=14)
    titre.fill = PatternFill(fgColor="003366", fill_type="solid")
    titre.alignment = Alignment(horizontal="center")
    ws.row_dimensions[1].height = 30
    
    # En-têtes colonnes (ligne 4)
    headers = ["Type erreur", "Chantier", "N° BL", "Réf. produit", 
               "Désignation", "Qté commandée", "Gratuité", "Qté attendue",
               "Qté facturée", "Écart qté", "Prix référentiel", 
               "Prix facturé", "Écart prix unit.", "Impact €", "Statut"]
    for col_idx, header in enumerate(headers, 1):
        cell = ws.cell(row=4, column=col_idx, value=header)
        cell.font = Font(bold=True)
        cell.fill = PatternFill(fgColor="E0E0E0", fill_type="solid")
    
    # Données
    row = 5
    couleurs = {
        "ERREUR_GRAVE": "FF4444",
        "ERREUR_QTE": "FF8C00", 
        "ERREUR_PRIX": "FF8C00",
        "GRATUITÉ_FACTURÉE": "FFD700",
        "NOUVEAU_PRODUIT": "90EE90",
        "PRIX_BAISSE": "90EE90",
    }
    
    for erreur in sorted(erreurs, key=lambda x: x.get("priorite", 99)):
        couleur = couleurs.get(erreur.get("type"), "FFFFFF")
        fill = PatternFill(fgColor=couleur, fill_type="solid")
        
        values = [
            erreur.get("type", ""),
            erreur.get("chantier", ""),
            erreur.get("num_bl", ""),
            erreur.get("ref_produit", ""),
            erreur.get("designation", ""),
            erreur.get("qte_commandee", ""),
            erreur.get("qte_gratuite", 0),
            erreur.get("qte_attendue", ""),
            erreur.get("qte_facturee", ""),
            erreur.get("ecart_qte", ""),
            erreur.get("prix_ref", ""),
            erreur.get("prix_facture", ""),
            erreur.get("ecart_prix", ""),
            erreur.get("impact_euros", ""),
            erreur.get("statut", ""),
        ]
        
        for col_idx, val in enumerate(values, 1):
            cell = ws.cell(row=row, column=col_idx, value=val)
            cell.fill = fill
            # Format monétaire pour les colonnes prix/impact
            if col_idx in [11, 12, 13, 14]:
                cell.number_format = '#,##0.00 €'
        row += 1
    
    # Ajuster largeurs
    col_widths = [20, 18, 15, 15, 35, 15, 12, 15, 15, 12, 16, 14, 16, 14, 15]
    for i, width in enumerate(col_widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = width
    
    wb.save(output_path)
    return output_path
```

## Exemples de lignes d'erreur

### Erreur de quantité (gratuité facturée) :
```
GRATUITÉ_FACTURÉE | KEVIN | 1182976 | 18062 | ANNEAU ECHAFFAUDAGE | 12 | 2 | 10 | 12 | +2 | 37,13 | 37,13 | 0,00 | 74,26 € | ⚠️ GRATUITÉ FACTURÉE
```

### Erreur de prix :
```
ERREUR_PRIX | SIMON | 1174993 | 17457 | ANNEAU ECHAFFAUDAGE | - | - | - | 2 | - | 37,00 | 37,13 | +0,13 | +0,26 € | ⚠️ PRIX SUPÉRIEUR
```

### Nouveau produit :
```
NOUVEAU_PRODUIT | JOAO | 1160402 | 4972 | WEBER.TENE XL+ T1 / 25 Kg | - | - | - | 16 | - | N/A | 41,47 | - | - | ℹ️ AJOUTÉ BASE
```
