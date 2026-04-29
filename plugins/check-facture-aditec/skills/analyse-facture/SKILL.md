---
name: analyse-facture
description: >
  Ce skill effectue l'analyse complète d'une facture ADITEC du mois : vérification des quantités
  par rapport au tableau de commandes (Excel) et vérification des prix par rapport au référentiel.
  Il se déclenche quand l'utilisatrice choisit "Analyser la facture du mois" dans le menu principal,
  ou dit "j'ai la facture du mois", "vérifier la facture", "analyser les commandes du mois".
metadata:
  version: "0.1.0"
---

## Objectif

Comparer chantier par chantier :
1. Les quantités facturées vs les quantités commandées (en tenant compte des gratuités)
2. Les prix facturés vs le référentiel de prix

Générer un fichier Excel de rapport avec toutes les erreurs détectées.

## Étape 1 — Identifier le mois

Utilise AskUserQuestion pour demander de quel mois il s'agit (c'est une question simple sans dépôt de fichier, AskUserQuestion est approprié ici).
Options : les 12 mois de l'année + l'année en cours.

## Étape 2 — Demander les fichiers

Afficher ce message et **s'arrêter** :

> "Pour analyser la facture de [MOIS], j'ai besoin de deux fichiers. Déposez-les tous les deux dans la conversation en même temps (ou l'un après l'autre), puis envoyez votre message :
> - La facture ADITEC du mois (PDF)
> - Votre tableau de commandes du mois (Excel)"

Ne pas utiliser AskUserQuestion. Ne pas continuer avant d'avoir reçu les deux fichiers dans la conversation.

Si un seul fichier est reçu, afficher :

> "J'ai bien reçu [nom du fichier]. Déposez maintenant [l'autre fichier manquant] dans la conversation."

Et s'arrêter à nouveau.

## Étape 3 — Extraction de la facture ADITEC

### Structure de la facture ADITEC

La facture est organisée en blocs, un bloc par bon de livraison :

```
BON DE LIVRAISON N° [NUM] [DATE]  COMMANDE N° [NUM] [DATE]  Réf. Commande : [CHANTIER]  Notre Référence : [LIEU]
[PRODUIT 1]    [REF]    [QTE]    [UNITE]    [PRIX_HT]    [MONTANT]    [TVA]
Couleur: [X.XX]                                                              ← ligne optionnelle sous la désignation
[PRODUIT 2]    [REF]    [QTE]    [UNITE]    [PRIX_HT]    [MONTANT]    [TVA]
 TOTAL HT [MONTANT]
```

### Règles d'extraction

Pour chaque bloc BL de la facture, extraire :
- `num_bl` : numéro du bon de livraison
- `date_bl` : date du BL
- `chantier` : valeur après "Réf. Commande :" (ex: "SIMON", "KEVIN", "JOAO")
- `lieu` : valeur après "Notre Référence :" si présent (ex: "PONT SCORFF", "LORIENT")
- `lignes` : liste des produits avec ref, désignation, qte, unite, prix_ht, **couleur**

### Extraction de la couleur — règle critique

**La couleur fait partie de la clé d'identification d'un produit.** Elle apparaît sur la ligne immédiatement sous la désignation du produit, précédée de "Couleur:".

```
MONODECOR GT P1 / 25 Kg    18062    165,00    SAC    6,24    1029,60    1
Couleur: J.10
MONODECOR GT P1 / 25 Kg    18062    255,00    SAC    6,24    1591,20    1
Couleur: J.40
```
→ Ce sont DEUX produits distincts pour l'analyse : (18062, J.10) et (18062, J.40)
→ La clé de comparaison est toujours : **(chantier, ref_produit, couleur)**

Pour les produits sans ligne "Couleur:", la couleur est `""` (chaîne vide).

**Cas particuliers :**
- **Quantités négatives** = avoir/retour (ex: -15,00 SAC). Les inclure comme avoirs dans le total du mois.
- **FRAIS DE DECHARGEMENT** (ref 7410) : ignorer pour l'analyse des prix.
- **FRAIS DE GESTION** (ref 18016) : ignorer complètement.
- **PARTICIPATION INDEXATION GASOIL** (ref 19440) : ignorer complètement.
- **Éco-contributions** (refs 990xxxx) : INCLURE dans la vérification des prix.
- **Chantier sans "Réf. Commande"** : utiliser "Notre Référence" comme identifiant de chantier.

### Agrégation par chantier ET par couleur

La même Réf. Commande peut apparaître dans plusieurs BL du mois. Agréger les quantités par **(chantier + référence produit + couleur)**.

Exemple :
- BL 1174993 : KEVIN, 18062, couleur "", 2 SAC
- BL 1182976 : KEVIN, 18062, couleur "", 2 SAC
→ Total KEVIN / 18062 / "" = **4 SAC** pour le mois

Exemple avec couleurs différentes sur un même chantier :
- BL 1159472 : PONT SCORFF, 18062, couleur "J.10", 165 SAC
- BL 1159472 : PONT SCORFF, 18062, couleur "J.40", 255 SAC
→ (PONT SCORFF, 18062, J.10) = 165 SAC — comparé séparément à la commande J.10
→ (PONT SCORFF, 18062, J.40) = 255 SAC — comparé séparément à la commande J.40

## Étape 4 — Extraction du tableau de commandes Excel

Le fichier Excel "TABLEAU COMMANDE [MOIS].xlsx" contient les commandes passées par l'entreprise.

### Structure attendue du tableau

Le tableau contient pour chaque ligne de commande :
- Nom du chantier (correspond à la Réf. Commande de la facture)
- Référence produit ou désignation
- Quantité commandée
- Unité
- Colonne "Gratuité" ou "dont gratuit" : quantité offerte par le fournisseur

**Lecture du fichier :**
Utiliser Python avec openpyxl ou pandas pour lire le fichier Excel :
```python
import pandas as pd
df = pd.read_excel("[CHEMIN]/TABLEAU COMMANDE [MOIS].xlsx")
```

**Logique des gratuités :**
Si commande = 12 SAC dont 2 gratuités → Quantité à facturer = 12 - 2 = 10 SAC
La facture doit montrer SOIT 10 SAC (net) SOIT "12 SAC - 2" avec une ligne de déduction.

Consulte `references/tableau-commandes.md` pour le détail du format Excel et la logique de matching chantier.

## Étape 5 — Analyse des quantités (priorité 1)

Pour chaque chantier du tableau de commandes :

### 5.1 Matching chantier
Trouver le chantier correspondant dans la facture. Le nom peut différer légèrement :
- Facture : "JOAO" → Excel : peut être "JOAO" ou "João" ou le nom du projet
- Facture : "FLEUR OCEAN" → Excel : peut être "FLEUR OCEAN" ou "FLEUR OCÉAN"
- Faire une correspondance insensible à la casse et aux accents

### 5.2 Calcul des quantités attendues
```
Qté attendue = Qté commandée - Qté gratuite
```

### 5.3 Comparaison
Pour chaque référence produit d'un chantier :
- `qte_commandee` = quantité dans le tableau Excel (colonne commande)
- `qte_gratuite` = quantité dans la colonne gratuité (0 si vide)
- `qte_attendue_facture` = qte_commandee - qte_gratuite
- `qte_facturee` = quantité totale sur la facture pour ce chantier + cette ref (agrégée sur tous les BL du mois)

**Erreurs à détecter — classées par gravité :**

🔴 **ERREUR GRAVE — Gratuité facturée à tort :**
La règle est : si qte_gratuite > 0 ET qte_facturee > (qte_commandee - qte_gratuite)
→ La gratuité a été facturée. C'est TOUJOURS une erreur grave, rouge vif dans le rapport.
→ Calculer le montant surfacturé = qte_gratuite × prix_ht
→ Message : "Chantier KEVIN — Ref 18062 / B.00 — 2 SAC gratuits FACTURÉS À TORT → surfacturation de X,XX €"

🔴 **ERREUR GRAVE — Surfacturation quantité + prix :**
qte_facturee > qte_attendue ET prix_facture > prix_ref → rouge vif

🟠 **ERREUR — Surfacturation en quantité (sans gratuité) :**
qte_facturee > qte_commandee (et qte_gratuite = 0)
→ Exemple : "Chantier KEVIN — Ref 18062 — Commandé 4 SAC, facturé 5 SAC → 1 SAC en trop"

🟠 **ERREUR — Surfacturation en prix uniquement :**
prix_facture > prix_ref (quelle que soit la quantité)

🟡 **À VÉRIFIER — Référence facturée sans commande connue :**
La référence apparaît sur la facture mais n'est pas dans le tableau de commandes du mois.

ℹ️ **INFO — Sous-facturation quantité :**
qte_facturee < qte_attendue → favorable, mais à signaler (livraison incomplète ?)

**La comparaison se fait toujours par triplet (chantier, ref_produit, couleur).**

## Étape 6 — Analyse des prix (priorité 2)

Pour chaque ligne de produit dans la facture :

1. Récupérer le prix de référence via la fonction `trouver_prix()` définie dans `check-facture/references/base-de-donnees.md` :
```python
# df_produits est chargé une seule fois en début d'analyse
df_produits = lire_produits(DOSSIER)
df_historique = lire_historique(DOSSIER)

# Pour chaque ligne de la facture :
prix_ref = trouver_prix(df_produits, ref, couleur)
# Retourne None si la référence est inconnue
```
2. Comparer le prix facturé avec le prix de référence

**Règles :**
- `prix_facture > prix_ref` → **ERREUR PRIX** : surfacturation
  - Calculer l'impact financier : (prix_facture - prix_ref) × quantité
  - Exemple : "Chantier SIMON — Ref 17457 — Prix ref 37,00 €, facturé 37,13 € → +0,13 €/BTE × 2 = +0,26 €"
- `prix_facture < prix_ref` → Mettre à jour silencieusement dans la base + noter en information
- `prix_facture = prix_ref` → OK, rien à signaler
- Référence inconnue → Ajouter à la base de prix + noter en information

**Tolérance : 0 centime** (zéro tolérance sur les prix, même 0,01 € doit être signalé).

## Étape 7 — Génération du rapport Excel

Créer un fichier Excel bien présenté. Consulte `references/format-rapport.md` pour le format exact.

**Nom du fichier : `RAPPORT_FACTURE_ADITEC.xlsx`** — toujours le même nom, dans le dossier Cowork.
Ce fichier est écrasé à chaque nouvelle analyse. Il n'y a jamais qu'un seul rapport à la fois.

```python
output_path = os.path.join(DOSSIER, "RAPPORT_FACTURE_ADITEC.xlsx")
# Si le fichier existe déjà, il sera écrasé — c'est voulu.
wb.save(output_path)
```

## Étape 8 — Synthèse à l'utilisatrice

Après le rapport, présenter un résumé en langage simple :

```
📊 Analyse de la facture de [MOIS] terminée !

J'ai analysé X chantiers et Y références produits.

🚨 ERREURS TROUVÉES : X problèmes à signaler au fournisseur
  - X erreurs de quantité (facturé en trop)
  - X erreurs de prix (prix supérieur au référentiel)

✅ Points positifs :
  - X prix facturés moins cher que votre référentiel (base mise à jour)

📄 Le rapport détaillé a été enregistré dans votre dossier :
   RAPPORT_FACTURE_ADITEC.xlsx
```

Si des erreurs importantes sont détectées, encourager l'utilisatrice à contacter ADITEC avec le rapport.
