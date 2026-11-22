-- STEP 6b: Journals with more than one Top-100 paper
-- (Excel chart: "Journal with Multiple Top 100 cited papers")

SELECT journal,
       COUNT(*)          AS n_papers,
       SUM(times_cited)  AS total_citations
FROM top100
GROUP BY journal
HAVING COUNT(*) > 1
ORDER BY n_papers DESC, total_citations DESC;
