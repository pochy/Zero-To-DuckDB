CREATE OR REPLACE TABLE raw.order_json_example AS
SELECT *
FROM (
  VALUES
    (
      'order_001',
      DATE '2026-05-10',
      [
        {'jan_code': '4900000000011', 'quantity': 2, 'unit_price': 1200},
        {'jan_code': '4900000000103', 'quantity': 5, 'unit_price': 150}
      ]
    ),
    (
      'order_002',
      DATE '2026-05-11',
      [
        {'jan_code': '4900000000042', 'quantity': 1, 'unit_price': 980},
        {'jan_code': '4900000000189', 'quantity': 1, 'unit_price': 3200}
      ]
    )
) AS t(order_id, order_date, items);

CREATE OR REPLACE TABLE mart.order_items_unnested AS
SELECT
  o.order_id,
  o.order_date,
  item.jan_code,
  item.quantity,
  item.unit_price,
  item.quantity * item.unit_price AS line_amount
FROM raw.order_json_example o,
UNNEST(o.items) AS u(item);

CREATE OR REPLACE TABLE mart.order_amount_summary AS
SELECT
  order_id,
  sum(line_amount) AS order_amount
FROM mart.order_items_unnested
GROUP BY ALL;

SELECT 'nested JSON UNNEST examples created' AS status;
