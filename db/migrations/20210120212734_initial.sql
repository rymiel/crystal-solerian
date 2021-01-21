-- +micrate Up
CREATE TABLE dict(
  hash TEXT PRIMARY KEY,
  eng TEXT NOT NULL,
  sol TEXT NOT NULL,
  extra TEXT NOT NULL,
  l INTEGER NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- +micrate Down
DROP TABLE dict;