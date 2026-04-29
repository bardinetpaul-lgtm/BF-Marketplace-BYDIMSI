---
name: ocr-feuilles-de-temps
description: >
  Utiliser ce skill pour effectuer l'OCR des feuilles de temps manuscrites PDF et générer
  le fichier Excel structuré. Se déclenche automatiquement après la sélection du mois, ou quand
  l'utilisateur dit "fais l'OCR", "extrais les heures", "génère le fichier Excel", "traite les PDFs",
  "lis les feuilles".
metadata:
  version: "0.3.0"
  author: "DIMSI"
---

## PROTOCOLE STRICT — UN SEUL PASSAGE PAR PAGE

**Tu es un transcripteur. Ton seul rôle est de lire et recopier.**

### Ce qui est INTERDIT (provoque des boucles infinies) :
- Recalculer ou vérifier si les totaux sont cohérents
- Comparer une valeur avec une autre
- Revenir en arrière sur un champ déjà écrit
- Exprimer un doute en plusieurs phrases
- Travailler "à rebours" depuis un total
- Relire une page déjà traitée
- Valider que les heures "s'additionnent correctement"

### Règle unique :
**Champ par champ, de haut en bas, une fois. Écrire ce qu'on voit. Passer au suivant.**

- Lisible → écrire la valeur, `conf: 85`
- Douteux → écrire le meilleur guess, `conf: 55`, `note: "peu lisible"`
- Illisible → écrire `"?"`, `conf: 30`, `note: "illisible"`

**Pas de phrase d'explication. Pas de raisonnement visible. Juste le JSON.**

---

## Conversions (faire silencieusement, sans commenter)

- `7H` `7h00` `7H00` → `"07:00"`
- `12H30` `12h30` → `"12:30"`
- Coche / croix / trait dans Montage → `1` — vide → `0`
- Jour sans aucune écriture → tous les champs `""`

---

## Format de sortie — une page = un objet JSON

Produire ce JSON immédiatement après avoir lu la page. Ne pas commencer à écrire avant d'avoir lu. Ne pas relire après avoir écrit.

```json
{
  "fichier": "nom.pdf",
  "semaine": 13,
  "employe": "DUPONT",
  "jours": [
    {"j":"Lundi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"17:00","tocr":"9h00", "chantier":"SPN",  "ville":"Quimper", "mont":1,"demont":0,"conf":88,"note":""},
    {"j":"Mardi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"16:45","tocr":"8h45", "chantier":"SPN",  "ville":"Quimper", "mont":1,"demont":0,"conf":82,"note":""},
    {"j":"Mercredi", "md":"",     "mf":"",     "ad":"",     "af":"",     "tocr":"",     "chantier":"",     "ville":"",        "mont":0,"demont":0,"conf":100,"note":""},
    {"j":"Jeudi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"17:00","tocr":"9h00", "chantier":"SBPI", "ville":"Lorient", "mont":0,"demont":1,"conf":60,"note":"chantier peu lisible"},
    {"j":"Vendredi", "md":"07:00","mf":"12:00","ad":"13:00","af":"15:00","tocr":"7h00", "chantier":"?",    "ville":"?",       "mont":0,"demont":0,"conf":35,"note":"illisible"}
  ]
}
```

---

## Exécution

1. Lire la page 1 → écrire l'objet JSON page 1 → s'arrêter
2. Lire la page 2 → écrire l'objet JSON page 2 → s'arrêter
3. Continuer jusqu'à la dernière page
4. Assembler le tableau final et l'écrire dans `/tmp/ocr_data.json`

```bash
python3 -c "
import json
data = [{...page1...}, {...page2...}, ...]
json.dump(data, open('/tmp/ocr_data.json','w'), ensure_ascii=False)
print('OK:', len(data), 'feuilles')
"
```
