# Règles d'extraction d'un devis ADITEC (Remise de Prix)

## Structure du document

Un devis ADITEC (intitulé "REMISE DE PRIX") contient :
- En-tête : Date, N° Pièce, Client (Barros Facades / code 300191)
- Sections thématiques numérotées : "1. SOUS ENDUIT", "2. ENDUIT LOURD", etc.
- Lignes de produits avec : Désignation | N° produit | Quantité | Unité | Prix HT | Montant | TVA
- Lignes de total de section ("Total 1. SOUS ENDUIT = 1122,72")
- Pied de page avec totaux HT, TVA, TTC

## Format d'une ligne produit

```
MONODECOR GT P1 / 25 Kg    18062    48,00    SAC    6,24    299,52    1
```
- Désignation : "MONODECOR GT P1 / 25 Kg"
- Référence : 18062
- Quantité : 48 (quantité de référence du devis — pour info seulement)
- Unité : SAC
- Prix unitaire HT : 6,24 € ← C'EST CE PRIX QUI COMPTE
- Montant total : 299,52 (= 48 × 6,24, ne pas utiliser)
- TVA groupe : 1 (taux normal) ou 3 (taux réduit pour éco-contrib)

## Lignes spéciales à traiter

### Éco-contributions
Format : "Eco-Contribution REP0.0087" avec référence commençant par 990...
```
Eco-Contribution REP0.88    9908800    35,00    PCE    0,88    30,80    3
```
→ INCLURE dans la base (ref: 9908800, prix: 0,88 €/PCE)

### Produits avec mention de couleur
```
MONODECOR GT P1 / 25 Kg    18062    48,00    SAC    6,24    299,52    1
Couleur: B.00
```
→ Dans le **devis**, la couleur est informative. Le prix est **identique quelle que soit la couleur** pour une même référence.
→ Dans la base, insérer une entrée générique sans couleur (couleur = "") depuis le devis : le prix s'applique à toutes les variantes de couleur.
→ Les entrées par couleur spécifique sont créées automatiquement quand on rencontre cette couleur sur un BL ou une facture.

**Résumé : devis → 1 entrée par référence (couleur vide) ; facture/BL → 1 entrée par (référence + couleur)**

### Lignes de section (à ignorer)
```
Total 1. SOUS ENDUIT    1122,72
```
→ Ne pas extraire, c'est un total intermédiaire

### Produits sans unité explicite (frais)
Certains produits n'ont pas d'unité (FRAIS DE DECHARGEMENT, etc.) — les inclure quand même avec unité = "PCE" par défaut.

## Sections du devis exemple PAREX 2026

1. SOUS ENDUIT — Enduits de base (PARMUREX, PARMUBRIK, MONOGRIS E, TRADIREX)
2. ENDUIT LOURD — Enduits lourds (MONODECOR GT, TL, GM, BLANC DU LITTORAL)
3. ENDUIT SEMI ALLEGE ET ALLEGE — (MONOREX GF, GM, MONOBLANCO)
4. RENOVATION ET BATI ANCIEN — (PARLUMIERE FIN/MOYEN, PARINTER, MAITE MONOCOMPOSANT)
5. DOSSIER ITE — (FACITE BLANC, COLLE CALISO, GRILLE VERRE, REVLANE, RAILS)
6. PSE 31 38 — Panneaux isolants (PSE BD GRIS)
7. ACCESSOIRES — Profilés, grilles, adhésifs, cornières

## Exemples de références à extraire du devis exemple

| Référence | Désignation | Unité | Prix HT |
|-----------|-------------|-------|---------|
| 18054 | PARMUREX / 25 Kg | SAC | 5,12 |
| 18127 | PARMUBRIK / 25 Kg | SAC | 6,95 |
| 18080 | MONOGRIS E / 25 Kg | SAC | 6,20 |
| 18055 | TRADIREX / 25 Kg | SAC | 5,12 |
| 18062 | MONODECOR GT P1 / 25 Kg | SAC | 6,24 |
| 18071 | MONODECOR TL / 25 Kg | SAC | 6,24 |
| 18060 | MONODECOR GM P1 / 25 Kg | SAC | 6,24 |
| 18070 | BLANC DU LITTORAL / 25 Kg | SAC | 6,24 |
| 17149 | MONOREX GF P1 / 25 Kg | SAC | 7,10 |
| 18082 | MONOREX GM P1 / 25 Kg | SAC | 7,10 |
| 16099 | MONOBLANCO / 25 Kg | SAC | 7,10 |
| 17375 | PARLUMIERE FIN / 25 Kg | SAC | 11,80 |
| 17376 | PARLUMIERE MOYEN / 25 Kg | SAC | 11,80 |
| 18056 | PARINTER RENOVATION / 25 Kg | SAC | 25,61 |
| 17391 | MAITE MONOCOMPOSANT / 25 Kg | SAC | 22,96 |
| 23067 | FACITE BLANC / 25 Kg | SAC | 14,75 |
| 20351 | COLLE CALISO / 25 Kg | SAC | 14,75 |
| 3660 | GRILLE VERRE R131 4X4 CSTB 50X1.10M | RLX | 36,50 |
| 9908800 | Eco-Contribution REP0.88 | PCE | 0,88 |
| 9829 | REVLANE + REGULATEUR / 20 Kg | SEA | 58,00 |
| 19705 | REVLANE SILOXANE TG 1.6 P1 / 25 Kg | SEA | 42,75 |
| 18577 | RAIL DE DEPART GE LO10/143 / 2.50 M | ML | 8,40 |
| 18576 | RAIL DE DEPART GE LO10/123 / 2.50 M | ML | 6,50 |
| 9431 | PSE BD GRIS Th31 Ep.140 (2.16) | M² | 12,60 |
| 9430 | PSE BD GRIS Th31 Ep.120 (2.88) | M² | 10,75 |
| 10968 | ADHESIF ST 211 ORANGE 72MM x 33 ML | Rlx | 3,64 |
| 3660 | GRILLE VERRE R131 4X4 CSTB 50X1.10M | RLX | 36,50 |
| 9875 | GRILLE DE VERRE R118 CSTB 50 X 1 M | RLX | 41,40 |
| 9876 | GRILLE DE VERRE R118 CSTB 50 X 0.5 | RLX | 21,56 |
| 12024 | PROFILE ANGLE 6001 BLANC 2.25 ML | ML | 0,78 |
| 12025 | PROFILE ANGLE 6001 BLANC 3 ML | ML | 0,78 |
| 12199 | PROFILE DILATATION 12MM BLANC 3 ML | ML | 8,50 |
| 13436 | ARRET JONC PVC BLANC AILE PERF 90° | ML | 2,55 |
| 13755 | ARRET PVC BLANC ENDUIT 6-8MM | ML | 2,90 |
| 18654 | CORNIERE ENTOILEE PVC PREM 300X100 | ML | 1,03 |
| 18655 | GOUTTE EAU CLIPSABLE ENTOILEE LEV06 | ML | 2,06 |
| 19836 | CORNIERE AV REP EP.10MM LK-H10 | ML | 3,09 |
| 19841 | CORNIERE AV REP EP.6MM LK-H06 | ML | 2,78 |

## Attention aux prix dans la facture de janvier 2026

Certains prix observés en facture diffèrent légèrement du devis :
- MONOBLANCO (16099) : facturé à 7,33 €/SAC (vs 7,10 dans le devis PAREX 2026)
- FONDAL 160µ (16834) : facturé à 53,25 €/RLX (vs 57,50 dans la facture de mars)
- TRADIREX (18055) : facturé à 6,05 €/SAC dans facture janvier (vs 5,12 dans devis)

Ces écarts peuvent refléter des prix antérieurs au devis. Toujours prendre le devis comme référence officielle.
