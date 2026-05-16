CREATE OR REPLACE TABLE mart.price_history_example AS
SELECT *
FROM (
  VALUES
    ('4900000000011', DATE '2026-05-01', 1200),
    ('4900000000011', DATE '2026-05-04', 1180),
    ('4900000000011', DATE '2026-05-08', 1210),
    ('4900000000042', DATE '2026-05-01', 980),
    ('4900000000042', DATE '2026-05-07', 990),
    ('4900000000103', DATE '2026-05-01', 150),
    ('4900000000103', DATE '2026-05-06', 155)
) AS t(jan_code, effective_from, price);

CREATE OR REPLACE TABLE mart.price_check_events AS
SELECT *
FROM (
  VALUES
    ('4900000000011', DATE '2026-05-02'),
    ('4900000000011', DATE '2026-05-06'),
    ('4900000000042', DATE '2026-05-08'),
    ('4900000000103', DATE '2026-05-03')
) AS t(jan_code, event_date);

CREATE OR REPLACE TABLE mart.price_at_event_asof AS
SELECT
  e.jan_code,
  e.event_date,
  h.effective_from AS matched_price_date,
  h.price AS price_at_event
FROM mart.price_check_events e
ASOF JOIN mart.price_history_example h
  ON e.jan_code = h.jan_code
 AND e.event_date >= h.effective_from;

SELECT 'ASOF JOIN examples created' AS status;
