---
name: traiter-feuilles-de-temps
description: >
  Skill principal à appeler manuellement pour lancer le traitement complet des feuilles de temps.
  L'utilisatrice uploade les PDFs directement dans la conversation. Le skill orchestre : sélection
  du mois, upload des PDFs, OCR, génération Excel rangé dans le bon dossier, import SQLite.
  Utiliser quand l'utilisateur ouvre le menu Skills, ou dit "traiter les feuilles", "lancer le
  traitement", "feuilles de temps", "j'ai mes scans", "traiter le mois de [mois]".
metadata:
  version: "0.6.0"
  author: "DIMSI"
---

## Principe

L'utilisatrice uploade ses PDFs → Claude transcrit → une commande Bash génère l'Excel → une commande Bash importe en SQLite.

---

## ÉTAPE 1 — QUEL MOIS ?

AskUserQuestion → "Quel mois souhaitez-vous traiter ?" avec ces boutons :

`Janvier` `Février` `Mars` `Avril` `Mai` `Juin` `Juillet` `Août` `Septembre` `Octobre` `Novembre` `Décembre`

Puis AskUserQuestion → "Quelle année ?" avec boutons : `2024` `2025` `2026` `2027`

Mémoriser : nom du mois (ex: `Mars`), numéro du mois sur 2 chiffres (ex: `03`), année (ex: `2026`).

---

## ÉTAPE 2 — UPLOAD DES PDFs

Afficher ce message :
> "Parfait ! Uploadez maintenant toutes les feuilles de temps de **[Mois] [Année]** directement dans cette conversation (glisser-déposer ou bouton trombone). Vous pouvez envoyer plusieurs fichiers en même temps."

Attendre que l'utilisatrice envoie ses fichiers. Dès qu'elle les envoie, continuer.

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

## ÉTAPE 4 — GÉNÉRER L'EXCEL

⛔ **NE PAS générer l'Excel manuellement. NE PAS utiliser openpyxl directement. Exécuter UNIQUEMENT la commande Bash ci-dessous.**

Remplacer `[CHEMIN_XLSX]` par le chemin complet :
`[workspace]/Feuilles de temps/[ANNÉE]/[MM] - [NomDuMois]/Heures_[NomDuMois]_[Année].xlsx`

Exemple : `/sessions/.../mnt/MonDossier/Feuilles de temps/2026/03 - Mars/Heures_Mars_2026.xlsx`

```bash
python3 - <<'ENDSCRIPT' /tmp/ocr_data.json "[CHEMIN_XLSX]"
import json,sys,os,subprocess
try: import openpyxl
except: subprocess.run([sys.executable,"-m","pip","install","openpyxl","--break-system-packages","-q"],check=True); import openpyxl
from openpyxl.styles import PatternFill,Font,Alignment
from openpyxl.comments import Comment
H_FILL=PatternFill("solid",fgColor="D9D9D9")
ERR_FILL=PatternFill("solid",fgColor="FFB347")
WARN_FILL=PatternFill("solid",fgColor="FFFF99")
TOT_FILL=PatternFill("solid",fgColor="BDD7EE")
ALT_FILL=PatternFill("solid",fgColor="F5F5F5")
H_FONT=Font(bold=True,size=10); T_FONT=Font(bold=True,size=10); N_FONT=Font(size=10)
HEADERS=["N° Sem","Nom Employé","Jour","Mat. Début","Mat. Fin","AM Début","AM Fin","Total (OCR)","Total (Calc.)","Écart","Nom Chantier","Ville","Montage","Démontage","Confiance %","Commentaire OCR"]
WIDTHS=[9,22,12,11,11,11,11,12,13,10,25,18,10,12,12,44]
COL_ECART=10; COL_COMMENT=16
JOURS={"Lundi":0,"Mardi":1,"Mercredi":2,"Jeudi":3,"Vendredi":4}
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
def wh(ws):
    for c,(h,w) in enumerate(zip(HEADERS,WIDTHS),1):
        cl=ws.cell(1,c,h); cl.fill=H_FILL; cl.font=H_FONT; cl.alignment=Alignment(horizontal="center")
        ws.column_dimensions[cl.column_letter].width=w
    ws.freeze_panes="A2"
def we(ws,f,row,alt):
    sem=f.get("semaine",""); emp=f.get("employe","")
    jours=sorted(f.get("jours",[]),key=lambda j:JOURS.get(j.get("j",""),9))
    tom=tcm=0; err=False
    for j in jours:
        md,mf,ad,af=j.get("md",""),j.get("mf",""),j.get("ad",""),j.get("af","")
        tocr=j.get("tocr",""); conf=j.get("conf",100); note=j.get("note","")
        mont="Oui" if j.get("mont") else ("Non" if md else "")
        dmt="Oui" if j.get("demont") else ("Non" if md else "")
        cm=calc(md,mf,ad,af); cs=fmt(cm); om=to_min(tocr)
        ecart=""; ie=False
        if om is not None and cm is not None:
            if abs(om-cm)>5: ecart="⚠️ ÉCART"; ie=True; err=True
            else: ecart="OK"
        if cm: tcm+=cm
        if om: tom+=om
        vals=[sem,emp,j.get("j",""),md,mf,ad,af,tocr,cs,ecart,j.get("chantier",""),j.get("ville",""),mont,dmt,conf,note]
        bg=ALT_FILL if alt else PatternFill()
        for c,v in enumerate(vals,1):
            cl=ws.cell(row,c,v); cl.font=N_FONT
            cl.fill=bg
            if ie and c==COL_ECART: cl.fill=ERR_FILL
            if conf<70 and c==COL_COMMENT: cl.fill=WARN_FILL
            if c==COL_COMMENT and note: cl.comment=Comment(note,"OCR")
        row+=1
    tr=[sem,emp,"TOTAL SEMAINE","","","","",fmt(tom),fmt(tcm),"⚠️ ÉCART" if err else "OK","","","","","",""]
    for c,v in enumerate(tr,1):
        cl=ws.cell(row,c,v); cl.fill=TOT_FILL; cl.font=T_FONT
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

Vérifier que la sortie commence par `OK:`. Présenter le fichier à l'utilisatrice.

AskUserQuestion → "Le fichier Excel est prêt ✅ Voulez-vous enregistrer les heures dans la base de données ?" → "▶ Oui, enregistrer" / "⏸ Je vérifie d'abord le fichier"

Si pause → "D'accord ! Quand vous êtes prête, dites-moi 'importer en base'." Stop.

---

## ÉTAPE 5 — IMPORTER EN BASE SQLite

Remplacer `[CHEMIN_DB]` par `[workspace]/Feuilles de temps/heures_chantiers.db`

```bash
python3 - <<'ENDSCRIPT' /tmp/ocr_data.json "[CHEMIN_DB]" [ANNEE] [MOIS_NUM]
import json,sys,os,sqlite3
from datetime import datetime
SQL="""
CREATE TABLE IF NOT EXISTS heures(id INTEGER PRIMARY KEY AUTOINCREMENT,annee INTEGER NOT NULL,mois INTEGER NOT NULL,num_semaine INTEGER NOT NULL,nom_employe TEXT NOT NULL,jour TEXT NOT NULL,matin_debut TEXT,matin_fin TEXT,apm_debut TEXT,apm_fin TEXT,total_ocr TEXT,total_calcule TEXT,ecart_total INTEGER DEFAULT 0,nom_chantier TEXT,ville_chantier TEXT,montage INTEGER DEFAULT 0,demontage INTEGER DEFAULT 0,confiance_pct INTEGER,commentaire_ocr TEXT,a_des_erreurs INTEGER DEFAULT 0,necessite_verification INTEGER DEFAULT 0,date_import TEXT NOT NULL,fichier_source TEXT);
CREATE TABLE IF NOT EXISTS notes_qualite(id INTEGER PRIMARY KEY AUTOINCREMENT,annee INTEGER NOT NULL,mois INTEGER NOT NULL,nom_fichier TEXT NOT NULL,note INTEGER NOT NULL CHECK(note BETWEEN 1 AND 10),commentaire TEXT,date_note TEXT NOT NULL);
"""
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
db=sys.argv[2]; os.makedirs(os.path.dirname(os.path.abspath(db)),exist_ok=True)
conn=sqlite3.connect(db); conn.executescript(SQL)
annee,mois=int(sys.argv[3]),int(sys.argv[4])
now=datetime.now().strftime("%Y-%m-%d %H:%M:%S"); total=0
for fe in data:
    sem=fe.get("semaine"); emp=fe.get("employe","")
    conn.execute("DELETE FROM heures WHERE annee=? AND mois=? AND num_semaine=? AND nom_employe=?",(annee,mois,sem,emp))
    for j in fe.get("jours",[]):
        md,mf,ad,af=j.get("md",""),j.get("mf",""),j.get("ad",""),j.get("af","")
        cm=calc(md,mf,ad,af); om=to_min(j.get("tocr",""))
        ecart=1 if(om is not None and cm is not None and abs(om-cm)>5) else 0
        conf=j.get("conf",100)
        conn.execute("INSERT INTO heures(annee,mois,num_semaine,nom_employe,jour,matin_debut,matin_fin,apm_debut,apm_fin,total_ocr,total_calcule,ecart_total,nom_chantier,ville_chantier,montage,demontage,confiance_pct,commentaire_ocr,a_des_erreurs,date_import,fichier_source) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (annee,mois,sem,emp,j.get("j",""),md,mf,ad,af,j.get("tocr",""),fmt(cm),ecart,j.get("chantier",""),j.get("ville",""),1 if j.get("mont") else 0,1 if j.get("demont") else 0,conf,j.get("note",""),1 if(ecart or conf<70) else 0,now,fe.get("fichier","")))
        total+=1
conn.commit(); conn.close(); print(f"OK:{total}")
ENDSCRIPT
```

Vérifier `OK:[N]`.

---

## ÉTAPE 6 — NOTE DE QUALITÉ ET FIN

AskUserQuestion → "Les heures sont enregistrées ✅ Sur 10, quelle note pour la qualité de lecture des écritures ?" → boutons `1` `2` `3` `4` `5` `6` `7` `8` `9` `10`

Stocker la note :
```bash
python3 -c "
import sqlite3,datetime
c=sqlite3.connect('[CHEMIN_DB]')
c.execute('CREATE TABLE IF NOT EXISTS notes_qualite(id INTEGER PRIMARY KEY AUTOINCREMENT,annee INTEGER NOT NULL,mois INTEGER NOT NULL,nom_fichier TEXT NOT NULL,note INTEGER NOT NULL CHECK(note BETWEEN 1 AND 10),commentaire TEXT,date_note TEXT NOT NULL)')
c.execute('INSERT INTO notes_qualite(annee,mois,nom_fichier,note,date_note) VALUES(?,?,?,?,?)',([AN],[MOIS],'Heures_[NomDuMois]_[AN].xlsx',[NOTE],datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
c.commit(); c.close(); print('OK')
"
```

**Note ≥ 7** → Récapitulatif final, terminé.

**Note 5-6** → AskUserQuestion : "Avez-vous des corrections à apporter au fichier Excel ?"
- "Oui, j'ai corrigé" → retour Étape 5 (re-import)
- "Non, c'est suffisant" → récapitulatif

**Note ≤ 4** → AskUserQuestion : "⚠️ Note faible. Souhaitez-vous corriger le fichier Excel avant de valider ?"
- "Oui, j'ai corrigé" → retour Étape 5
- "Importer quand même" → re-import avec flag `necessite_verification`, récapitulatif
- "Annuler" → "Rien n'a été enregistré. Le fichier Excel est disponible pour correction."

**Récapitulatif final :**
```
🎉 [Mois] [Année] traité avec succès !
📁 Excel rangé dans : Feuilles de temps/[Année]/[MM] - [Mois]/
👥 [N] employé(s)  •  📅 Semaines [liste]  •  📊 [N] lignes enregistrées  •  ⭐ [note]/10
```
