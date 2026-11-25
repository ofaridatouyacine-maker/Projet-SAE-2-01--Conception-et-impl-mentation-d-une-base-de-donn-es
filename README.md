# Base de données bancaire en PostgreSQL — SAÉ 2.01

Projet réalisé en binôme au semestre 2 du BUT Science des données (IUT Clermont Auvergne, site d'Aurillac), avec Madeleine Alexandrie Matemb.

## Le contexte

Une petite banque clermontoise gérait toutes ses données (clients, comptes, agents, mouvements) dans un seul fichier CSV. À partir du cahier des charges du directeur d'agence, nous avons conçu et mis en place une vraie base de données relationnelle.

## Ce que j'ai fait

- Modélisation des entités et production du **MCD** et des **schémas relationnels normalisés**
- Écriture du script SQL PostgreSQL : création des **7 tables** (agents, clients, comptes, mouvements, parrainages et tables de liaison) avec leurs clés primaires et étrangères
- Import du fichier CSV d'origine dans une table temporaire, puis répartition des données dans les tables
- Création de **vues** pour répondre aux questions du directeur :
  - `v_comptes_dormants` : les comptes sans mouvement depuis longtemps
  - `v_etat_parrainages` : le suivi des parrainages par agent

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| `sql/banque.sql` | Script complet : création des tables, import, insertions et vues |
| `resultats/` | Résultats des deux vues exportés en CSV |
| `rapport/` | Rapport du projet (PDF lisible directement sur GitHub, et version Word) |

## Outils

PostgreSQL · SQL · modélisation MCD / MLD

## Pour lancer le script

Créer une base `banque` dans PostgreSQL, adapter le chemin du fichier CSV dans la commande `COPY`, puis exécuter `sql/banque.sql`.
