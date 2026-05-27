---
name: traiter-feuilles-de-temps
description: >
  Skill principal à appeler manuellement pour lancer le traitement complet des feuilles de temps.
  L'utilisatrice uploade les PDFs directement dans la conversation. Le skill orchestre : sélection
  du mois, upload des PDFs, OCR, génération Excel rangé dans le bon dossier, enregistrement CSV.
  Utiliser quand l'utilisateur ouvre le menu Skills, ou dit "traiter les feuilles", "lancer le
  traitement", "feuilles de temps", "j'ai mes scans", "traiter le mois de [mois]".
metadata:
  version: "0.9.0"
  author: "DIMSI"
---

## Principe

L'utilisatrice uploade ses PDFs → Claude transcrit → l'Excel est généré automatiquement → les heures sont enregistrées.

## ⛔ LANGAGE INTERDIT

Ne jamais utiliser ces mots ou expressions dans les messages à l'utilisatrice :
- JSON, SQLite, CSV, base de données, script, Python, Bash, commande, terminal, fichier temporaire, /tmp, openpyxl, import, variable, fonction, log, erreur système, Linux, parsing

Parler uniquement en termes métier : "feuilles de temps", "heures", "fichier Excel", "enregistrement", "liste du personnel".

---

## ÉTAPE 1 — QUEL MOIS ?

AskUserQuestion → "Quel mois souhaitez-vous traiter ?" avec ces boutons :

`Janvier` `Février` `Mars` `Avril` `Mai` `Juin` `Juillet` `Août` `Septembre` `Octobre` `Novembre` `Décembre`

S'arrêter. Attendre la réponse. Ne pas enchaîner d'autres questions.

---

## ÉTAPE 1b — QUELLE ANNÉE ?

AskUserQuestion → "Quelle année ?" avec boutons : `2024` `2025` `2026` `2027`

S'arrêter. Attendre la réponse.

Mémoriser : nom du mois (ex: `Mars`), numéro du mois sur 2 chiffres (ex: `03`), année (ex: `2026`).

---

## ÉTAPE 2 — UPLOAD DES PDFs

Afficher uniquement ce message texte, rien d'autre. Ne pas utiliser AskUserQuestion. Ne pas afficher de bouton d'upload :
> "Parfait ! Envoyez-moi maintenant toutes les feuilles de temps de **[Mois] [Année]** (glisser-déposer ou bouton trombone). Vous pouvez envoyer plusieurs fichiers en même temps."

S'arrêter. Attendre que l'utilisatrice envoie ses fichiers dans la conversation. Ne rien afficher d'autre avant de les recevoir.

---

## ÉTAPE 3 — TRANSCRIPTION (protocole strict, un seul passage)

### INTERDIT — ces comportements causent des boucles infinies :
- Recalculer ou vérifier si les totaux sont cohérents
- Travailler "à rebours" depuis un total cumulé
- Relire une page déjà traitée
- Comparer une valeur d'une page avec une autre
- Exprimer un doute en plusieurs phrases ou "wait, let me re-read"
- Tenter de réconcilier des chiffres qui ne s'additionnent pas

### Règle unique :
**Lire la page une fois de haut en bas. Écrire ce qu'on voit. Produire le JSON. Passer à la page suivante.**

- Lisible → valeur + `"conf":85`
- Douteux → meilleur guess + `"conf":55` + `"note":"peu lisible"`
- Illisible → `"?"` + `"conf":30` + `"note":"illisible"`

```json
{"fichier":"nom.pdf","semaine":13,"employe":"DUPONT",
 "jours":[
   {"j":"Lundi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"17:00","tocr":"9h00","chantier":"SPN", "ville":"Quimper","mont":1,"demont":0,"conf":88,"note":""},
   {"j":"Mardi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"16:45","tocr":"8h45","chantier":"SPN", "ville":"Quimper","mont":1,"demont":0,"conf":82,"note":""},
   {"j":"Mercredi", "md":"",     "mf":"",     "ad":"",     "af":"",    "tocr":"",    "chantier":"",    "ville":"",       "mont":0,"demont":0,"conf":100,"note":""},
   {"j":"Jeudi",    "md":"07:00","mf":"12:00","ad":"13:00","af":"17:00","tocr":"9h00","chantier":"SBPI","ville":"Lorient","mont":0,"demont":1,"conf":60,"note":"chantier peu lisible"},
   {"j":"Vendredi", "md":"07:00","mf":"12:00","ad":"13:00","af":"15:00","tocr":"7h00","chantier":"?",  "ville":"?",      "mont":0,"demont":0,"conf":35,"note":"illisible"}
 ]}
```

Conversions silencieuses : `7H`→`"07:00"` / `12H30`→`"12:30"` / coche ou croix→`1` / vide→`0` / jour sans travail→champs `""`

Après toutes les pages, assembler et sauvegarder :
```bash
python3 -c "
import json
data = [{...p1...},{...p2...}]
json.dump(data, open('/tmp/ocr_data.json','w'), ensure_ascii=False)
print('OK:', len(data), 'feuilles')
"
```

---

## ÉTAPE 3b — CONFIRMATION DES NOMS

Extraire la liste des noms d'employés lus dans les feuilles (champ `employe` de chaque objet JSON).

Afficher ce message à l'utilisatrice :
> "J'ai lu les feuilles de temps pour les personnes suivantes. Est-ce que les noms sont corrects ?
>
> [Liste numérotée des noms, ex : 1. STEPHAN  2. RUI  3. TONNERRE Thomas  4. KELVIN  5. DESSYPOM]
>
> Si un nom est mal orthographié, dites-moi le numéro et la correction. Sinon, répondez **C'est bon**."

Attendre la réponse de l'utilisatrice :
- Si elle dit "C'est bon" ou équivalent → continuer à l'étape 4
- Si elle corrige un ou plusieurs noms → mettre à jour le champ `employe` correspondant dans les données, mémoriser les corrections pour les prochaines fois, puis afficher la liste corrigée et redemander confirmation

---

## ÉTAPE 4 — GÉNÉRER L'EXCEL

Chemin cible : `[workspace]/Feuilles de temps/[ANNÉE]/[MM] - [NomDuMois]/Heures_[NomDuMois]_[Année].xlsx`

### Méthode principale — Bash

Essayer d'abord cette commande. Si elle retourne `OK:` → continuer. Si elle échoue (erreur sandbox, etc.) → passer au fallback sans rien dire à l'utilisatrice.

```bash
python3 - <<'ENDSCRIPT' /tmp/ocr_data.json "[CHEMIN_XLSX]"
import json,sys,os,subprocess,datetime
try: import openpyxl
except: subprocess.run([sys.executable,"-m","pip","install","openpyxl","--break-system-packages","-q"],check=True); import openpyxl
from openpyxl.styles import PatternFill,Font,Alignment
from openpyxl.comments import Comment
from openpyxl.formatting.rule import FormulaRule
H_FILL=PatternFill("solid",fgColor="D9D9D9")
ERR_FILL=PatternFill("solid",fgColor="FFB347")
WARN_FILL=PatternFill("solid",fgColor="FFFF99")
TOT_FILL=PatternFill("solid",fgColor="BDD7EE")
ALT_FILL=PatternFill("solid",fgColor="F5F5F5")
H_FONT=Font(bold=True,size=10); T_FONT=Font(bold=True,size=10); N_FONT=Font(size=10)
HEADERS=["N° Sem","Nom Employé","Jour","Mat. Début","Mat. Fin","AM Début","AM Fin","Total (OCR)","Total (Calc.)","Écart","Nom Chantier","Ville","Montage","Démontage","Confiance %","Commentaire OCR"]
WIDTHS=[9,22,12,11,11,11,11,12,13,10,25,18,10,12,12,44]
COL_COMMENT=16
JOURS={"Lundi":0,"Mardi":1,"Mercredi":2,"Jeudi":3,"Vendredi":4}
TIME_FMT="h:mm"
CALC_FMT="[h]:mm"
def to_min(s):
    if not s or str(s).strip()=="": return None
    s=str(s).strip().lower().replace("h",":")
    p=s.split(":")
    try: return int(p[0])*60+(int(p[1]) if len(p)>1 and p[1] else 0)
    except: return None
def to_time(s):
    if not s or str(s).strip()=="": return None
    s=str(s).strip().lower().replace("h",":")
    p=s.split(":")
    try:
        h=int(p[0]); m=int(p[1]) if len(p)>1 and p[1] else 0
        return datetime.time(h,m)
    except: return None
def fmt(m): return "" if m is None else f"{m//60}h{m%60:02d}"
def wh(ws):
    for c,(h,w) in enumerate(zip(HEADERS,WIDTHS),1):
        cl=ws.cell(1,c,h); cl.fill=H_FILL; cl.font=H_FONT; cl.alignment=Alignment(horizontal="center")
        ws.column_dimensions[cl.column_letter].width=w
    ws.freeze_panes="A2"
    ws.conditional_formatting.add('J2:J1000',FormulaRule(formula=['J2="⚠️ ÉCART"'],fill=ERR_FILL))
def we(ws,f,row,alt):
    sem=f.get("semaine",""); emp=f.get("employe","")
    jours=sorted(f.get("jours",[]),key=lambda j:JOURS.get(j.get("j",""),9))
    tom=0; data_start=row
    for j in jours:
        md,mf,ad,af=j.get("md",""),j.get("mf",""),j.get("ad",""),j.get("af","")
        tocr=j.get("tocr",""); conf=j.get("conf",100); note=j.get("note","")
        mont="Oui" if j.get("mont") else ("Non" if md else "")
        dmt="Oui" if j.get("demont") else ("Non" if md else "")
        om=to_min(tocr)
        if om: tom+=om
        bg=ALT_FILL if alt else PatternFill()
        # Colonnes statiques (texte)
        for c,v in [(1,sem),(2,emp),(3,j.get("j","")),(8,tocr),(11,j.get("chantier","")),(12,j.get("ville","")),(13,mont),(14,dmt),(15,conf),(16,note)]:
            cl=ws.cell(row,c,v); cl.font=N_FONT; cl.fill=bg
            if conf<70 and c==COL_COMMENT: cl.fill=WARN_FILL
            if c==COL_COMMENT and note: cl.comment=Comment(note,"OCR")
        # Cellules heures — vraies valeurs temps Excel (colonnes D=4, E=5, F=6, G=7)
        for col,src in [(4,md),(5,mf),(6,ad),(7,af)]:
            tv=to_time(src)
            cl=ws.cell(row,col,tv if tv is not None else "")
            cl.font=N_FONT; cl.fill=bg
            if tv is not None: cl.number_format=TIME_FMT
        # Total (Calc.) — formule dynamique (colonne I=9)
        cl=ws.cell(row,9,f'=IF(OR(D{row}="",E{row}="",F{row}="",G{row}=""),"",(E{row}-D{row})+(G{row}-F{row}))')
        cl.font=N_FONT; cl.fill=bg; cl.number_format=CALC_FMT
        # Écart — formule dynamique (colonne J=10)
        cl=ws.cell(row,10,f'=IF(OR(H{row}="",I{row}=""),"",IFERROR(IF(ABS(I{row}-TIMEVALUE(SUBSTITUTE(H{row},"h",":")))>TIME(0,5,0),"⚠️ ÉCART","OK"),"⚠️ ÉCART"))')
        cl.font=N_FONT; cl.fill=bg
        row+=1
    data_end=data_start+len(jours)-1
    # Ligne TOTAL SEMAINE
    for c,v in [(1,sem),(2,emp),(3,"TOTAL SEMAINE"),(8,fmt(tom)),(10,""),(11,""),(12,""),(13,""),(14,""),(15,""),(16,"")]:
        cl=ws.cell(row,c,v); cl.fill=TOT_FILL; cl.font=T_FONT
    for c in [4,5,6,7]:
        cl=ws.cell(row,c,""); cl.fill=TOT_FILL; cl.font=T_FONT
    # Total Calc. — formule SUM dynamique sur les lignes de données
    cl=ws.cell(row,9,f'=SUM(I{data_start}:I{data_end})')
    cl.fill=TOT_FILL; cl.font=T_FONT; cl.number_format=CALC_FMT
    return row+2
with open(sys.argv[1],encoding="utf-8") as f: data=json.load(f)
out=sys.argv[2]; os.makedirs(os.path.dirname(os.path.abspath(out)),exist_ok=True)
wb=openpyxl.Workbook(); wb.remove(wb.active)
sems={}
for d in data: sems.setdefault(d.get("semaine",0),[]).append(d)
for s in sorted(sems):
    ws=wb.create_sheet(f"Semaine {s:02d}"); wh(ws); row=2
    for i,fe in enumerate(sems[s]): row=we(ws,fe,row,i%2==1)
wb.save(out); print(f"OK:{out}")
ENDSCRIPT
```

### Fallback — si Bash échoue

Générer un fichier CSV de secours avec l'outil Write, même structure que l'Excel, même chemin mais extension `.csv` :
`[workspace]/Feuilles de temps/[ANNÉE]/[MM] - [NomDuMois]/Heures_[NomDuMois]_[Année].csv`

Colonnes exactes dans cet ordre (séparateur `;`) :
`N° Sem;Nom Employé;Jour;Mat. Début;Mat. Fin;AM Début;AM Fin;Total (OCR);Total (Calc.);Écart;Nom Chantier;Ville;Montage;Démontage;Confiance %;Commentaire OCR`

Règles de calcul pour chaque ligne :
- `Total (Calc.)` = (Mat.Fin - Mat.Début) + (AM Fin - AM Début), format `Xh00`
- `Écart` = `⚠️ ÉCART` si différence > 5 min entre Total OCR et Total Calc., sinon `OK`
- Après les 5 jours de chaque employé : ligne `TOTAL SEMAINE` avec somme des totaux
- Alternance de blocs employés séparés par une ligne vide

Écrire le fichier avec l'outil Write directement dans le workspace.

Quand c'est prêt (via l'une ou l'autre méthode), afficher simplement :
> "Le fichier des heures de [Mois] [Année] est prêt ✅"

AskUserQuestion → "Voulez-vous enregistrer les heures ?" → "▶ Oui, enregistrer" / "⏸ Je vérifie d'abord le fichier"

Si pause → "D'accord ! Quand vous êtes prête, dites-moi 'enregistrer les heures'." Stop.

---

## ÉTAPE 5 — ENREGISTRER LES HEURES

Chemin cible : `[workspace]/Feuilles de temps/heures.csv`

### Méthode principale — Bash

Essayer d'abord. Si `OK:` en sortie → continuer. Sinon → fallback silencieux.

```bash
python3 - <<'ENDSCRIPT' /tmp/ocr_data.json "[CHEMIN_CSV]" [ANNEE] [MOIS_NUM]
import json,sys,os,csv
from datetime import datetime
def to_min(s):
    if not s or str(s).strip()=="": return None
    s=str(s).strip().lower().replace("h",":")
    p=s.split(":")
    try: return int(p[0])*60+(int(p[1]) if len(p)>1 and p[1] else 0)
    except: return None
def fmt(m): return "" if m is None else f"{m//60}h{m%60:02d}"
def calc(a,b,c,d):
    v=[to_min(x) for x in [a,b,c,d]]
    if any(x is None for x in v): return None
    return (v[1]-v[0])+(v[3]-v[2])
with open(sys.argv[1],encoding="utf-8") as f: data=json.load(f)
csv_path=sys.argv[2]; annee,mois=int(sys.argv[3]),int(sys.argv[4])
now=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
os.makedirs(os.path.dirname(os.path.abspath(csv_path)),exist_ok=True)
HEADERS=["annee","mois","num_semaine","nom_employe","jour","matin_debut","matin_fin","apm_debut","apm_fin","total_ocr","total_calcule","ecart","nom_chantier","ville","montage","demontage","confiance_pct","commentaire_ocr","a_des_erreurs","date_import","fichier_source"]
existing=[]
if os.path.exists(csv_path):
    with open(csv_path,encoding="utf-8",newline="") as f:
        for row in csv.DictReader(f):
            if not(int(row["annee"])==annee and int(row["mois"])==mois): existing.append(row)
new_rows=[]
for fe in data:
    sem=fe.get("semaine"); emp=fe.get("employe",""); fichier=fe.get("fichier","")
    for j in fe.get("jours",[]):
        md,mf,ad,af=j.get("md",""),j.get("mf",""),j.get("ad",""),j.get("af","")
        cm=calc(md,mf,ad,af); om=to_min(j.get("tocr","")); conf=j.get("conf",100)
        ecart=1 if(om is not None and cm is not None and abs(om-cm)>5) else 0
        new_rows.append({"annee":annee,"mois":mois,"num_semaine":sem,"nom_employe":emp,"jour":j.get("j",""),"matin_debut":md,"matin_fin":mf,"apm_debut":ad,"apm_fin":af,"total_ocr":j.get("tocr",""),"total_calcule":fmt(cm),"ecart":ecart,"nom_chantier":j.get("chantier",""),"ville":j.get("ville",""),"montage":1 if j.get("mont") else 0,"demontage":1 if j.get("demont") else 0,"confiance_pct":conf,"commentaire_ocr":j.get("note",""),"a_des_erreurs":1 if(ecart or conf<70) else 0,"date_import":now,"fichier_source":fichier})
with open(csv_path,encoding="utf-8",newline="",mode="w") as f:
    writer=csv.DictWriter(f,fieldnames=HEADERS)
    writer.writeheader()
    for row in existing: writer.writerow(row)
    for row in new_rows: writer.writerow(row)
print(f"OK:{len(new_rows)}")
ENDSCRIPT
```

### Fallback — si Bash échoue

Construire le contenu CSV en mémoire à partir des données OCR et l'écrire avec l'outil Write.

Colonnes exactes (séparateur `,`) :
`annee,mois,num_semaine,nom_employe,jour,matin_debut,matin_fin,apm_debut,apm_fin,total_ocr,total_calcule,ecart,nom_chantier,ville,montage,demontage,confiance_pct,commentaire_ocr,a_des_erreurs,date_import,fichier_source`

Règles :
- `total_calcule` = (Mat.Fin - Mat.Début) + (AM Fin - AM Début), format `Xh00`
- `ecart` = `1` si différence > 5 min, sinon `0`
- `a_des_erreurs` = `1` si ecart=1 ou confiance_pct < 70, sinon `0`
- `date_import` = date et heure actuelles format `YYYY-MM-DD HH:MM:SS`
- Si le fichier existe déjà : lire les lignes existantes, supprimer celles du même `annee`+`mois`, réécrire tout avec les nouvelles lignes ajoutées

Écrire avec l'outil Write dans `[workspace]/Feuilles de temps/heures.csv`.

Afficher simplement :
> "Les heures de [Mois] [Année] sont bien enregistrées ✅"

---

## ÉTAPE 6 — NOTE DE QUALITÉ ET FIN

AskUserQuestion → "Sur 10, quelle note donnez-vous à la qualité de lecture des écritures manuscrites ?" → boutons `1` `2` `3` `4` `5` `6` `7` `8` `9` `10`

Stocker la note (remplacer `[CHEMIN_NQ]` par `[workspace]/Feuilles de temps/notes_qualite.csv`) :
```bash
python3 - <<'ENDSCRIPT' "[CHEMIN_NQ]" [ANNEE] [MOIS_NUM] "Heures_[NomDuMois]_[AN].xlsx" [NOTE]
import csv,sys,os
from datetime import datetime
path=sys.argv[1]; annee=int(sys.argv[2]); mois=int(sys.argv[3])
nom=sys.argv[4]; note=int(sys.argv[5])
now=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
os.makedirs(os.path.dirname(os.path.abspath(path)),exist_ok=True)
HEADERS=["annee","mois","nom_fichier","note","date_note"]
exists=os.path.exists(path)
with open(path,encoding="utf-8",newline="",mode="a") as f:
    writer=csv.DictWriter(f,fieldnames=HEADERS)
    if not exists: writer.writeheader()
    writer.writerow({"annee":annee,"mois":mois,"nom_fichier":nom,"note":note,"date_note":now})
print("OK")
ENDSCRIPT
```

**Note ≥ 7** → Récapitulatif final, terminé.

**Note 5-6** → AskUserQuestion : "Souhaitez-vous corriger le fichier avant de finaliser ?"
- "Oui, j'ai corrigé" → retour Étape 5
- "Non, c'est suffisant" → récapitulatif

**Note ≤ 4** → AskUserQuestion : "⚠️ Plusieurs écritures étaient difficiles à lire. Voulez-vous corriger le fichier avant de valider ?"
- "Oui, j'ai corrigé" → retour Étape 5
- "Enregistrer quand même" → re-enregistrement, récapitulatif
- "Annuler" → "D'accord, rien n'a été enregistré. Le fichier reste disponible si vous souhaitez le corriger."

**Récapitulatif final :**
```
🎉 [Mois] [Année] traité avec succès !
📁 Fichier rangé dans : Feuilles de temps / [Année] / [MM] - [Mois]
👥 [N] employé(s)  •  📅 Semaines [liste]  •  📊 [N] lignes enregistrées  •  ⭐ [note]/10
```
