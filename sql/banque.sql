-- SAE2-01 : Base de données bancaire - PostgreSQL
-- Script final  avec toutes les modifications

-- ÉTAPE 1 : CRÉATION DE LA BASE
-- CREATE DATABASE banque;

-- ÉTAPE 2 : CRÉATION DES TABLES
CREATE TABLE AGENT (
    id_agent   BIGINT PRIMARY KEY,
    nom        VARCHAR(100),
    prenom     VARCHAR(100),
    civilite   CHAR(1),
    ddn        DATE
);

CREATE TABLE CLIENT (
    id_client  BIGINT PRIMARY KEY,
    nom        VARCHAR(100),
    prenom     VARCHAR(100),
    civilite   CHAR(1),
    ddn        DATE,
    adresse    VARCHAR(255),
    cp         VARCHAR(10),
    ville      VARCHAR(100)
);

CREATE TABLE GERER (
    id_agent   BIGINT NOT NULL REFERENCES AGENT(id_agent),
    id_client  BIGINT NOT NULL REFERENCES CLIENT(id_client),
    PRIMARY KEY (id_agent, id_client)
);

CREATE TABLE COMPTE (
    num_cpt            BIGINT PRIMARY KEY,
    designation_compte VARCHAR(100),
    date_ouverture     DATE
);

CREATE TABLE DETENIR (
    id_client  BIGINT NOT NULL REFERENCES CLIENT(id_client),
    num_cpt    BIGINT NOT NULL REFERENCES COMPTE(num_cpt),
    PRIMARY KEY (id_client, num_cpt)
);

CREATE TABLE MOUVEMENT (
    id_mouvement          INTEGER PRIMARY KEY,
    dt_mouvement          DATE,
    montant               NUMERIC(12,2),
    designation_mouvement VARCHAR(255),
    num_cpt               BIGINT NOT NULL REFERENCES COMPTE(num_cpt)
);

CREATE TABLE PARRAINER (
    id_client_1     BIGINT NOT NULL REFERENCES CLIENT(id_client),
    id_client_2     BIGINT NOT NULL REFERENCES CLIENT(id_client),
    date_parrainage DATE,
    PRIMARY KEY (id_client_1, id_client_2)
);

-- ÉTAPE 3 : TABLE TEMPORAIRE POUR IMPORT CSV
-- Toutes les colonnes en VARCHAR pour éviter les erreurs de dates invalides
CREATE TABLE tmp_banque (
    id_client             VARCHAR(100),
    nom                   VARCHAR(100),
    prenom                VARCHAR(100),
    civilite              CHAR(1),
    ddn                   VARCHAR(20),
    adresse               VARCHAR(255),
    cp                    VARCHAR(10),
    ville                 VARCHAR(100),
    date_rattachement     VARCHAR(20),
    type_rattachement     VARCHAR(50),
    numcpt                VARCHAR(20),
    designation_compte    VARCHAR(100),
    id_mouvement          VARCHAR(20),
    dt_mouvement          VARCHAR(20),
    montant               VARCHAR(20),
    designation_mouvement VARCHAR(255),
    parrain               VARCHAR(100),
    date_parrainage       VARCHAR(20),
    matricule_agent       VARCHAR(20),
    nom_agent             VARCHAR(200),
    ddn_agent             VARCHAR(20),
    civilite_agent        CHAR(1)
);

-- Importer le CSV dans tmp_banque :
COPY tmp_banque FROM 'C:/data/sae_donnees_bancaires.csv'
WITH (FORMAT CSV, HEADER, DELIMITER ',', ENCODING 'UTF8');

-- ÉTAPE 4 : ALIMENTATION DES TABLES
-- Agent
INSERT INTO AGENT (id_agent, nom, prenom, civilite, ddn)
SELECT DISTINCT
    matricule_agent::BIGINT,
    SPLIT_PART(nom_agent, ' ', 2),
    SPLIT_PART(nom_agent, ' ', 1),
    civilite_agent,
    ddn_agent::DATE
FROM tmp_banque
ON CONFLICT DO NOTHING;

-- Client (sans ddn à cause de dates invalides dans le CSV)
INSERT INTO CLIENT (id_client, nom, prenom, civilite, adresse, cp, ville)
SELECT DISTINCT ON (id_client)
    id_client::BIGINT,
    nom,
    prenom,
    civilite,
    adresse,
    cp,
    ville
FROM tmp_banque
ORDER BY id_client;

-- Compte (sans date_ouverture à cause de dates invalides dans le CSV)
INSERT INTO COMPTE (num_cpt, designation_compte)
SELECT DISTINCT
    numcpt::BIGINT,
    designation_compte
FROM tmp_banque
ON CONFLICT DO NOTHING;

-- Gerer
INSERT INTO GERER (id_agent, id_client)
SELECT DISTINCT
    matricule_agent::BIGINT,
    id_client::BIGINT
FROM tmp_banque
ON CONFLICT DO NOTHING;

-- Detenir
INSERT INTO DETENIR (id_client, num_cpt)
SELECT DISTINCT
    id_client::BIGINT,
    numcpt::BIGINT
FROM tmp_banque
ON CONFLICT DO NOTHING;

-- Mouvement (sans dt_mouvement pour l'instant)
INSERT INTO MOUVEMENT (id_mouvement, montant, designation_mouvement, num_cpt)
SELECT DISTINCT
    id_mouvement::INTEGER,
    montant::NUMERIC(12,2),
    designation_mouvement,
    numcpt::BIGINT
FROM tmp_banque
ON CONFLICT DO NOTHING;

-- Mise à jour des dates valides dans MOUVEMENT
UPDATE mouvement
SET dt_mouvement = tmp_banque.dt_mouvement::DATE
FROM tmp_banque
WHERE mouvement.id_mouvement::TEXT = tmp_banque.id_mouvement
AND tmp_banque.dt_mouvement NOT LIKE '%-02-29';

-- Remplacement des 29 février invalides par le 28 février
UPDATE mouvement
SET dt_mouvement = REPLACE(tmp_banque.dt_mouvement, '-02-29', '-02-28')::DATE
FROM tmp_banque
WHERE mouvement.id_mouvement::TEXT = tmp_banque.id_mouvement
AND tmp_banque.dt_mouvement LIKE '%-02-29';

-- Parrainer
INSERT INTO PARRAINER (id_client_1, id_client_2)
SELECT DISTINCT parrain_client.id_client, t.id_client::BIGINT
FROM tmp_banque t
JOIN CLIENT parrain_client ON parrain_client.nom = t.parrain
WHERE t.parrain IS NOT NULL AND t.parrain <> '';

-- Mise à jour des dates de parrainage
UPDATE parrainer
SET date_parrainage = tmp_banque.date_parrainage::DATE
FROM tmp_banque
JOIN client parrain_client ON parrain_client.nom = tmp_banque.parrain
WHERE parrainer.id_client_1 = parrain_client.id_client
AND parrainer.id_client_2 = tmp_banque.id_client::BIGINT
AND tmp_banque.date_parrainage IS NOT NULL
AND tmp_banque.date_parrainage <> '';

-- ÉTAPE 5 : CRÉATION DES VUES

-- 5.1 Comptes dormants
-- Affiche les comptes dont le dernier mouvement est avant le 31/12 de l'année précédente
CREATE OR REPLACE VIEW v_comptes_dormants AS
SELECT
    c.nom                        AS nom_client,
    co.num_cpt                   AS numero_compte,
    MAX(m.dt_mouvement)          AS dernier_mouvement,
    SUM(m.montant)               AS solde
FROM client c
JOIN detenir d   ON c.id_client = d.id_client
JOIN compte co   ON d.num_cpt   = co.num_cpt
JOIN mouvement m ON co.num_cpt  = m.num_cpt
GROUP BY c.nom, co.num_cpt
HAVING MAX(m.dt_mouvement) < DATE '2022-01-01'
ORDER BY dernier_mouvement;

-- 5.2 État des parrainages
-- en testant on observe que les données de parranaiges date des années 90 si on met le filtre a
-- 2022 on aurra aucune données du coup on a utilisé un filtre généraliste
CREATE OR REPLACE VIEW v_etat_parrainages AS
SELECT
    a.nom                  AS nom_agent,
    cp.nom                 AS nom_parrain,
    cf.nom                 AS nom_filleul,
    p.date_parrainage,
    m.dt_mouvement         AS date_mouvement_parrainage
FROM parrainer p
JOIN client cp   ON p.id_client_1 = cp.id_client
JOIN client cf   ON p.id_client_2 = cf.id_client
JOIN gerer g     ON cp.id_client  = g.id_client
JOIN agent a     ON g.id_agent    = a.id_agent
LEFT JOIN mouvement m
    ON m.num_cpt IN (
        SELECT num_cpt FROM detenir WHERE id_client = cp.id_client
    )
    AND m.designation_mouvement ILIKE '%parrainage%'
ORDER BY p.date_parrainage

-- ÉTAPE 6 : EXPORTS CSV

-- Export comptes dormants
copy (SELECT * FROM v_comptes_dormants) TO 'C:/data/comptes_dormants.csv' WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'UTF8');

-- Export état des parrainages
copy (SELECT * FROM v_etat_parrainages) TO 'C:/data/etat_parrainages.csv' WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'UTF8');



-- VÉRIFICATIONS


SELECT COUNT(*) AS nb_agents      FROM agent;
SELECT COUNT(*) AS nb_clients     FROM client;
SELECT COUNT(*) AS nb_comptes     FROM compte;
SELECT COUNT(*) AS nb_mouvements  FROM mouvement;
SELECT COUNT(*) AS nb_parrainages FROM parrainer;

SELECT * FROM v_comptes_dormants  LIMIT 10;
SELECT * FROM v_etat_parrainages  LIMIT 10;
