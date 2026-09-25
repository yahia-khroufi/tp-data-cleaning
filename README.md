# Data Cleaning & Data Quality with Oracle SQL

Ce projet regroupe une série de travaux pratiques autour de la **qualité des données**, de la **détection d'anomalies** et du **nettoyage de données** avec **Oracle SQL / PL/SQL**.

L'objectif est de mettre en pratique différentes techniques de manipulation, d'importation, d'analyse et de correction des données dans une base Oracle.

---

## Objectifs

Ce projet permet notamment de travailler sur :

- la création et l'alimentation d'une base de données ;
- l'exploration des métadonnées Oracle ;
- la manipulation de données avec SQL et PL/SQL ;
- la création et l'utilisation de procédures et fonctions ;
- l'importation de données avec **SQL\*Loader** ;
- la détection de valeurs manquantes et d'anomalies ;
- l'identification de valeurs répétées ou incohérentes ;
- la visualisation d'indicateurs de qualité ;
- le nettoyage et la correction des données.

---

## Technologies utilisées

- Oracle Database
- SQL
- PL/SQL
- SQL\*Loader
- Oracle Data Dictionary
- Docker
- SQL*Plus / SQL Developer

---

## Structure du projet

```text
tp-data-cleaning/
│
├── create_dataset/
│   ├── 2026-B99-MFB01-MetaDonnees.sql
│   ├── 2026-B99-MFB02-BiblioFoncProc.sql
│   ├── 2026-B99-MFB03-CreatInsertDonGCF-SQL.sql
│   ├── 2026-B99-MFB04-ManipDonGCF-SQLAvance.sql
│   ├── 2026-B99-MFB05-ManipDonGCF-SQLLOADER.sql
│   └── 2026-B99-MFB06-DataAnomaly-Visu-Clean.sql
│
├── procedures_complementaires/
│   └── ...
│
├── docs/
│   └── ...
│
├── logs/
│   └── ...
│
└── README.md
```

---

## Description des scripts

| Script | Description |
|---|---|
| `MFB01-MetaDonnees.sql` | Exploration des métadonnées et de la structure de la base |
| `MFB02-BiblioFoncProc.sql` | Bibliothèque de fonctions et procédures PL/SQL |
| `MFB03-CreatInsertDonGCF-SQL.sql` | Création des tables et insertion des données |
| `MFB04-ManipDonGCF-SQLAvance.sql` | Manipulations et requêtes SQL avancées |
| `MFB05-ManipDonGCF-SQLLOADER.sql` | Importation de données avec SQL\*Loader |
| `MFB06-DataAnomaly-Visu-Clean.sql` | Détection, visualisation et nettoyage des anomalies |

Le dossier `procedures_complementaires/` contient les procédures supplémentaires nécessaires à certains exercices de qualité et de nettoyage des données.

---

## Workflow

Le projet suit globalement le processus suivant :

```text
Création des données
        ↓
Exploration des métadonnées
        ↓
Manipulation SQL / PL/SQL
        ↓
Importation avec SQL*Loader
        ↓
Détection des anomalies
        ↓
Analyse de la qualité
        ↓
Nettoyage des données
```

---

## Exécution avec Oracle

Les scripts peuvent être exécutés depuis **SQL*Plus**, **SQL Developer** ou un autre client Oracle.

Exemple avec SQL*Plus :

```bash
sqlplus system@freepdb1
```

Puis :

```sql
@2026-B99-MFB03-CreatInsertDonGCF-SQL.sql
```

Les scripts doivent être exécutés dans l'ordre lorsque des dépendances existent entre eux.

---

## Oracle avec Docker

Le projet peut également être exécuté avec une instance Oracle dans Docker.

Exemple :

```bash
docker run -d \
  --name oracle-db \
  -p 1521:1521 \
  -e ORACLE_PASSWORD=oracle \
  gvenzl/oracle-free:23-slim
```

Connexion :

```bash
docker exec -it oracle-db sqlplus system/oracle@freepdb1
```

---

## SQL*Loader

Certaines données peuvent être chargées depuis des fichiers externes grâce à **SQL\*Loader**.

Exemple :

```bash
sqlldr userid=SYSTEM/oracle@freepdb1 control=Controler.txt
```

Un fichier de contrôle définit notamment :

- le fichier source ;
- la table cible ;
- le séparateur utilisé ;
- la correspondance entre les colonnes du fichier et celles de la table.

---

## Data Quality

Les exercices abordent plusieurs dimensions importantes de la qualité des données :

- **Complétude** : recherche de valeurs manquantes ;
- **Unicité** : recherche de doublons et répétitions ;
- **Validité** : vérification du respect des règles attendues ;
- **Cohérence** : détection de valeurs contradictoires ;
- **Exactitude** : identification de valeurs potentiellement anormales.

---

## Exemple de détection d'anomalies

Une anomalie peut correspondre à :

```text
Valeur manquante
Valeur dupliquée
Format incorrect
Valeur hors intervalle
Valeur incohérente
Violation d'une règle métier
```

L'objectif n'est donc pas uniquement de supprimer des données, mais de :

```text
Détecter → Comprendre → Corriger → Vérifier
```

---

## Compétences développées

Ce projet permet de renforcer les compétences suivantes :

- SQL avancé
- PL/SQL
- procédures et fonctions Oracle
- Data Quality
- Data Cleaning
- Data Profiling
- SQL*Loader
- métadonnées Oracle
- automatisation de contrôles de qualité
- utilisation d'Oracle avec Docker

---

## Auteur

**Yahia Khroufi**

Master Web Intelligence & Data Science  
Data Engineering / Data Science