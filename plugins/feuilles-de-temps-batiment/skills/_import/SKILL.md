---
name: _import
description: >
  Utiliser ce skill pour enregistrer les données dans les fichiers CSV,
  recueillir la note de qualité OCR, et gérer la boucle de correction. Se déclenche automatiquement
  après la génération du fichier Excel, ou quand l'utilisateur dit "importer en base",
  "enregistrer les heures", "sauvegarder", "mettre à jour",
  "j'ai corrigé le fichier Excel". Gère aussi les re-imports après correction manuelle.
metadata:
  version: "0.2.0"
  author: "DIMSI"
---

## Objectif

Enregistrer toutes les heures dans deux fichiers CSV : `heures.csv` et `notes_qualite.csv`, situés à la racine du dossier "Feuilles de temps". La stratégie est SUPPRIMER puis RÉINSÉRER pour le mois concerné — propre et sans doublons.

## Fichiers CSV

**`heures.csv`** — une ligne par jour travaillé :
```
annee,mois,num_semaine,nom_employe,jour,matin_debut,matin_fin,apm_debut,apm_fin,total_ocr,total_calcule,ecart,nom_chantier,ville,montage,demontage,confiance_pct,commentaire_ocr,a_des_erreurs,date_import,fichier_source
```

**`notes_qualite.csv`** — une ligne par traitement mensuel :
```
annee,mois,nom_fichier,note,date_note
```

## Commande d'enregistrement

⛔ Exécuter UNIQUEMENT cette commande Bash. Ne pas écrire le CSV manuellement.

Remplacer `[CHEMIN_CSV]` par `[workspace]/Feuilles de temps/heures.csv` et `[CHEMIN_NQ]` par `[workspace]/Feuilles de temps/notes_qualite.csv`.

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
csv_path=sys.argv[2]
annee,mois=int(sys.argv[3]),int(sys.argv[4])
now=datetime.now().strftime("%Y-%m-%d %H:%M:%S")

os.makedirs(os.path.dirname(os.path.abspath(csv_path)),exist_ok=True)

HEADERS=["annee","mois","num_semaine","nom_employe","jour","matin_debut","matin_fin","apm_debut","apm_fin","total_ocr","total_calcule","ecart","nom_chantier","ville","montage","demontage","confiance_pct","commentaire_ocr","a_des_erreurs","date_import","fichier_source"]

# Lire les lignes existantes et supprimer celles du mois traité
existing=[]
if os.path.exists(csv_path):
    with open(csv_path,encoding="utf-8",newline="") as f:
        reader=csv.DictReader(f)
        for row in reader:
            if not(int(row["annee"])==annee and int(row["mois"])==mois):
                existing.append(row)

# Construire les nouvelles lignes
new_rows=[]
for fe in data:
    sem=fe.get("semaine"); emp=fe.get("employe",""); fichier=fe.get("fichier","")
    for j in fe.get("jours",[]):
        md,mf,ad,af=j.get("md",""),j.get("mf",""),j.get("ad",""),j.get("af","")
        cm=calc(md,mf,ad,af); om=to_min(j.get("tocr",""))
        ecart=1 if(om is not None and cm is not None and abs(om-cm)>5) else 0
        conf=j.get("conf",100)
        new_rows.append({
            "annee":annee,"mois":mois,"num_semaine":sem,"nom_employe":emp,
            "jour":j.get("j",""),"matin_debut":md,"matin_fin":mf,"apm_debut":ad,"apm_fin":af,
            "total_ocr":j.get("tocr",""),"total_calcule":fmt(cm),"ecart":ecart,
            "nom_chantier":j.get("chantier",""),"ville":j.get("ville",""),
            "montage":1 if j.get("mont") else 0,"demontage":1 if j.get("demont") else 0,
            "confiance_pct":conf,"commentaire_ocr":j.get("note",""),
            "a_des_erreurs":1 if(ecart or conf<70) else 0,
            "date_import":now,"fichier_source":fichier
        })

# Réécrire le CSV complet
with open(csv_path,encoding="utf-8",newline="",mode="w") as f:
    writer=csv.DictWriter(f,fieldnames=HEADERS)
    writer.writeheader()
    for row in existing: writer.writerow(row)
    for row in new_rows: writer.writerow(row)

print(f"OK:{len(new_rows)}")
ENDSCRIPT
```

Vérifier que la sortie commence par `OK:`.

## Enregistrer la note de qualité

```bash
python3 - <<'ENDSCRIPT' "[CHEMIN_NQ]" [ANNEE] [MOIS_NUM] "[NOM_FICHIER]" [NOTE]
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

## Règles importantes

- Ne jamais écrire dans les CSV manuellement
- Les lignes "TOTAL SEMAINE" du fichier Excel ne sont pas enregistrées
- En cas d'erreur, informer l'utilisatrice simplement sans termes techniques
- Langage interdit : CSV, script, Python, colonne, ligne de code, parsing
