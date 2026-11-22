-- STEP 3a: VALIDATION CHECKS
-- Goal: make sure the data "makes sense" before we trust it.
-- Each row of the result is one check. bad_rows = how many records fail it.
-- (SUM(CASE WHEN ... THEN 1 ELSE 0 END) is a common SQL trick to COUNT rows that match a rule.)

SELECT 'total rows'                         AS check_name, COUNT(*) AS bad_rows FROM papers
UNION ALL
SELECT 'missing Web of Science ID (ut)',    SUM(CASE WHEN ut IS NULL OR ut = '' THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'missing title',                     SUM(CASE WHEN title IS NULL OR title = '' THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'missing authors',                   SUM(CASE WHEN authors IS NULL OR authors = '' THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'missing DOI',                       SUM(CASE WHEN doi IS NULL THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'DOI in wrong format (not 10.xxx)',  SUM(CASE WHEN doi IS NOT NULL AND doi NOT LIKE '10.%' THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'missing author keywords',           SUM(CASE WHEN author_keywords IS NULL THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'missing affiliations',              SUM(CASE WHEN affiliations IS NULL THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'year missing or out of range',      SUM(CASE WHEN pub_year IS NULL OR pub_year < 1900 OR pub_year > 2026 THEN 1 ELSE 0 END) FROM papers
UNION ALL
SELECT 'citations missing or negative',     SUM(CASE WHEN times_cited IS NULL OR times_cited < 0 THEN 1 ELSE 0 END) FROM papers;
