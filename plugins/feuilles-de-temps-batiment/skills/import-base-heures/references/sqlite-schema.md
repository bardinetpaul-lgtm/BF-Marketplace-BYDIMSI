# Schéma SQLite — Base des heures chantiers

## Localisation

Fichier : `heures_chantiers.db`  
Emplacement : **racine du dossier "Feuilles de temps"** dans le projet  
Exemple : `Feuilles de temps/heures_chantiers.db`

## Tables

### Table `heures`

Stocke chaque ligne de travail : 1 employé × 1 jour.

```sql
CREATE TABLE IF NOT EXISTS heures (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    annee            INTEGER NOT NULL,
    mois             INTEGER NOT NULL,
    num_semaine      INTEGER NOT NULL,
    semaine_du       TEXT,
    semaine_au       TEXT,
    nom_employe      TEXT NOT NULL,
    jour             TEXT NOT NULL,
    matin_debut      TEXT,
    matin_fin        TEXT,
    apm_debut        TEXT,
    apm_fin          TEXT,
    total_ocr        TEXT,
    total_calcule    TEXT,
    ecart_total      INTEGER DEFAULT 0,   -- 1 si écart détecté
    nom_chantier     TEXT,
    ville_chantier   TEXT,
    montage          INTEGER DEFAULT 0,   -- 1 = Oui
    demontage        INTEGER DEFAULT 0,   -- 1 = Oui
    confiance_pct    INTEGER,             -- Score moyen OCR (0-100)
    commentaire_ocr  TEXT,
    a_des_erreurs    INTEGER DEFAULT 0,   -- 1 si écart ou confiance < 70%
    necessite_verification INTEGER DEFAULT 0,  -- 1 si note OCR ≤ 4 et import forcé
    date_import      TEXT NOT NULL,       -- ISO : YYYY-MM-DD HH:MM:SS
    fichier_source   TEXT
);
```

### Table `notes_qualite`

Stocke les notes de qualité OCR données par la secrétaire après chaque traitement.

```sql
CREATE TABLE IF NOT EXISTS notes_qualite (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    annee        INTEGER NOT NULL,
    mois         INTEGER NOT NULL,
    nom_fichier  TEXT NOT NULL,
    note         INTEGER NOT NULL CHECK (note BETWEEN 1 AND 10),
    commentaire  TEXT,
    date_note    TEXT NOT NULL    -- ISO : YYYY-MM-DD HH:MM:SS
);
```

## Script Python complet d'initialisation et d'import

```python
import sqlite3
import os
from datetime import datetime

def init_database(db_path):
    """Crée la base et les tables si elles n'existent pas."""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS heures (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            annee            INTEGER NOT NULL,
            mois             INTEGER NOT NULL,
            num_semaine      INTEGER NOT NULL,
            semaine_du       TEXT,
            semaine_au       TEXT,
            nom_employe      TEXT NOT NULL,
            jour             TEXT NOT NULL,
            matin_debut      TEXT,
            matin_fin        TEXT,
            apm_debut        TEXT,
            apm_fin          TEXT,
            total_ocr        TEXT,
            total_calcule    TEXT,
            ecart_total      INTEGER DEFAULT 0,
            nom_chantier     TEXT,
            ville_chantier   TEXT,
            montage          INTEGER DEFAULT 0,
            demontage        INTEGER DEFAULT 0,
            confiance_pct    INTEGER,
            commentaire_ocr  TEXT,
            a_des_erreurs    INTEGER DEFAULT 0,
            necessite_verification INTEGER DEFAULT 0,
            date_import      TEXT NOT NULL,
            fichier_source   TEXT
        );

        CREATE TABLE IF NOT EXISTS notes_qualite (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            annee        INTEGER NOT NULL,
            mois         INTEGER NOT NULL,
            nom_fichier  TEXT NOT NULL,
            note         INTEGER NOT NULL CHECK (note BETWEEN 1 AND 10),
            commentaire  TEXT,
            date_note    TEXT NOT NULL
        );
    """)
    conn.commit()
    conn.close()


def supprimer_doublon(conn, annee, mois, num_semaine, nom_employe):
    """Supprime les lignes existantes pour éviter les doublons."""
    conn.execute("""
        DELETE FROM heures
        WHERE annee = ? AND mois = ? AND num_semaine = ? AND nom_employe = ?
    """, (annee, mois, num_semaine, nom_employe))


def importer_ligne(conn, ligne, annee, mois, fichier_source, necessite_verification=0):
    """Insère une ligne de données dans la table heures."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute("""
        INSERT INTO heures (
            annee, mois, num_semaine, semaine_du, semaine_au,
            nom_employe, jour,
            matin_debut, matin_fin, apm_debut, apm_fin,
            total_ocr, total_calcule, ecart_total,
            nom_chantier, ville_chantier,
            montage, demontage,
            confiance_pct, commentaire_ocr,
            a_des_erreurs, necessite_verification,
            date_import, fichier_source
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        annee, mois,
        ligne['num_semaine'], ligne['semaine_du'], ligne['semaine_au'],
        ligne['nom_employe'], ligne['jour'],
        ligne['matin_debut'], ligne['matin_fin'],
        ligne['apm_debut'], ligne['apm_fin'],
        ligne['total_ocr'], ligne['total_calcule'],
        1 if ligne.get('ecart') == '⚠️ ÉCART' else 0,
        ligne['nom_chantier'], ligne['ville_chantier'],
        1 if ligne.get('montage') == 'Oui' else 0,
        1 if ligne.get('demontage') == 'Oui' else 0,
        ligne.get('confiance_pct'),
        ligne.get('commentaire_ocr', ''),
        1 if (ligne.get('ecart') == '⚠️ ÉCART' or (ligne.get('confiance_pct') or 100) < 70) else 0,
        necessite_verification,
        now, fichier_source
    ))


def stocker_note(db_path, annee, mois, nom_fichier, note, commentaire=''):
    """Stocke la note de qualité OCR."""
    conn = sqlite3.connect(db_path)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    conn.execute("""
        INSERT INTO notes_qualite (annee, mois, nom_fichier, note, commentaire, date_note)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (annee, mois, nom_fichier, note, commentaire, now))
    conn.commit()
    conn.close()
```

## Requêtes utiles pour consultation

```sql
-- Toutes les heures d'un mois donné
SELECT nom_employe, num_semaine, jour, matin_debut, matin_fin,
       apm_debut, apm_fin, total_calcule, nom_chantier, ville_chantier
FROM heures
WHERE annee = 2026 AND mois = 3
ORDER BY nom_employe, num_semaine, 
    CASE jour 
        WHEN 'Lundi' THEN 1 WHEN 'Mardi' THEN 2 WHEN 'Mercredi' THEN 3 
        WHEN 'Jeudi' THEN 4 WHEN 'Vendredi' THEN 5 
    END;

-- Total d'heures par employé sur un mois (depuis total_calcule)
SELECT nom_employe, COUNT(*) AS nb_jours_travailles
FROM heures
WHERE annee = 2026 AND mois = 3 AND matin_debut IS NOT NULL
GROUP BY nom_employe;

-- Chantiers uniques référencés
SELECT DISTINCT nom_chantier, ville_chantier 
FROM heures 
WHERE nom_chantier IS NOT NULL AND nom_chantier != ''
ORDER BY ville_chantier, nom_chantier;

-- Lignes nécessitant une vérification
SELECT nom_employe, jour, total_ocr, total_calcule, commentaire_ocr
FROM heures 
WHERE a_des_erreurs = 1 OR necessite_verification = 1
ORDER BY annee, mois, num_semaine, nom_employe;

-- Historique des notes de qualité
SELECT annee, mois, nom_fichier, note, date_note
FROM notes_qualite
ORDER BY date_note DESC;

-- Moyenne des notes par mois
SELECT annee, mois, ROUND(AVG(note), 1) AS note_moyenne, COUNT(*) AS nb_traitements
FROM notes_qualite
GROUP BY annee, mois
ORDER BY annee, mois;
```
