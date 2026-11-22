-- STEP 4: SELECT THE TOP 100 MOST-CITED PAPERS
-- Same logic as the original Google Sheets QUERY:
--   select * where M is not null order by M desc limit 100
-- FILTER out missing citation counts, SORT highest first, keep the first 100.
-- row_id (original file order) breaks ties so the result is the same every run.
-- RANK() gives a citation rank (tied papers share a rank).

CREATE TABLE top100 AS
SELECT
    RANK() OVER (ORDER BY times_cited DESC) AS citation_rank,
    ut, doi, title, authors, first_author, senior_author, senior_author_key, n_authors,
    journal, pub_year, times_cited, doc_type, author_keywords, affiliations
FROM papers_dedup
WHERE times_cited IS NOT NULL
ORDER BY times_cited DESC, row_id ASC
LIMIT 100;
