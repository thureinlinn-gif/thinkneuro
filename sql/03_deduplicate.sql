-- STEP 3c: DEDUPLICATE
-- Keep exactly ONE row per Web of Science ID.
-- ROW_NUMBER() is a "window function": inside each group of rows with the same ut
-- (PARTITION BY ut) it numbers them 1, 2, 3... We keep only row number 1.
-- If a paper did appear twice, we keep the copy with the most citations
-- (and the earlier row in the file if that is also tied).

CREATE TABLE papers_dedup AS
SELECT *
FROM (
    SELECT p.*,
           ROW_NUMBER() OVER (
               PARTITION BY ut
               ORDER BY times_cited DESC, row_id ASC
           ) AS copy_number
    FROM papers AS p
)
WHERE copy_number = 1;
