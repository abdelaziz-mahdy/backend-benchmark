CREATE TABLE IF NOT EXISTS note (
  id serial PRIMARY KEY,
  title text NOT NULL,
  content text NOT NULL
);