-- Une ligne par répondant. Le détail vit en JSON : la page a été refondue une
-- demi-douzaine de fois, une colonne par question aurait demandé autant de
-- migrations. Seuls les champs sur lesquels on compte ou on trie en sortent.
CREATE TABLE IF NOT EXISTS reponses (
  id      TEXT PRIMARY KEY,        -- jeton du navigateur, posé en cookie
  nom     TEXT NOT NULL,
  cle     TEXT NOT NULL,           -- nom normalisé : empêche le doublon
  nb      INTEGER NOT NULL DEFAULT 1,
  vient   INTEGER NOT NULL DEFAULT 1,
  donnees TEXT NOT NULL DEFAULT '{}',
  cree    INTEGER NOT NULL,
  maj     INTEGER NOT NULL
);

-- Le garde-fou contre la double réponse : deux navigateurs, un même nom, une
-- seule ligne. Le second passage met à jour au lieu d'ajouter.
CREATE UNIQUE INDEX IF NOT EXISTS reponses_cle ON reponses(cle);
