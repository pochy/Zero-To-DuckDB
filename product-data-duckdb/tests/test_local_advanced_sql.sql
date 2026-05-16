SELECT
  CASE
    WHEN (
      SELECT string_agg(reader || ':' || row_count, ',' ORDER BY reader)
      FROM mart.auto_reader_probe
    ) = 'csv_auto:7,json_auto:5'
      THEN 'PASS: auto readers inspect expected input rows'
    ELSE error('FAIL: auto reader probe mismatch')
  END AS result;

SELECT
  CASE
    WHEN (
      SELECT count(*)
      FROM mart.normalized_profile
      WHERE column_name IN ('price', 'ocr_confidence')
    ) = 2
      THEN 'PASS: summarize profile includes numeric quality columns'
    ELSE error('FAIL: summarize profile missing expected columns')
  END AS result;

SELECT
  CASE
    WHEN (SELECT count(*) FROM mart.order_items_unnested) = 4
      THEN 'PASS: UNNEST expands nested order items'
    ELSE error('FAIL: UNNEST row count mismatch')
  END AS result;

SELECT
  CASE
    WHEN (
      SELECT price_at_event
      FROM mart.price_at_event_asof
      WHERE jan_code = '4900000000011'
        AND event_date = DATE '2026-05-06'
    ) = 1180
      THEN 'PASS: ASOF JOIN finds latest price before event'
    ELSE error('FAIL: ASOF JOIN matched price mismatch')
  END AS result;

SELECT
  CASE
    WHEN (
      SELECT min(row_count)
      FROM mart.export_option_summary
    ) = 11
      THEN 'PASS: export option examples preserve row counts'
    ELSE error('FAIL: export option row count mismatch')
  END AS result;
