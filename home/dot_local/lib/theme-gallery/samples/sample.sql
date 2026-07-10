-- Palette sample: SQL — comments, keywords, strings, numbers, functions.
CREATE TABLE greeting (
    id      INTEGER PRIMARY KEY,
    name    TEXT    NOT NULL DEFAULT 'world',
    ratio   REAL    CHECK (ratio BETWEEN 0.0 AND 1.0)
);

INSERT INTO greeting (id, name) VALUES (1, 'palette');

SELECT id, upper(name) AS shout
FROM greeting
WHERE ratio > 0.5
ORDER BY id DESC
LIMIT 3;
