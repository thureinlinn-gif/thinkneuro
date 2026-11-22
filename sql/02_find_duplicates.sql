-- STEP 3b: FIND DUPLICATES
-- We check three ways a paper could appear twice:
--   1) same Web of Science ID (ut)       -> the main "unique ID"
--   2) same DOI                          -> backup check
--   3) same title (already lowercased)   -> backup check, catches records with no DOI
-- GROUP BY puts identical values together; HAVING COUNT(*) > 1 keeps only values that repeat.

SELECT 'ut' AS matched_on, ut AS value, COUNT(*) AS times_seen
FROM papers
GROUP BY ut
HAVING COUNT(*) > 1

UNION ALL

SELECT 'doi', doi, COUNT(*)
FROM papers
WHERE doi IS NOT NULL
GROUP BY doi
HAVING COUNT(*) > 1

UNION ALL

SELECT 'title', title_key, COUNT(*)
FROM papers
GROUP BY title_key
HAVING COUNT(*) > 1;
