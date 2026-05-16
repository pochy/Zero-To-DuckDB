CREATE TABLE IF NOT EXISTS categories (
  category_id INTEGER PRIMARY KEY,
  category_name TEXT NOT NULL UNIQUE
);

INSERT INTO categories (category_id, category_name) VALUES
  (1, 'food'),
  (2, 'electronics'),
  (3, 'stationery'),
  (4, 'home'),
  (5, 'beauty')
ON CONFLICT (category_id) DO UPDATE
SET category_name = EXCLUDED.category_name;

CREATE TABLE IF NOT EXISTS metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO metadata (key, value) VALUES
  ('source', 'postgres docker seed')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;
