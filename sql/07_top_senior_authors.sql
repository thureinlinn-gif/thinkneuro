-- STEP 6c: Senior authors (last author = usually the lab head) with more than one Top-100 paper
-- (Excel chart: "Senior Authors with Multiple Top-100 Papers")
-- We group on senior_author_key (lowercased) so "Abel, T" and "abel, t" count as one person.

SELECT MIN(senior_author)  AS senior_author,
       COUNT(*)            AS n_papers,
       SUM(times_cited)    AS total_citations
FROM top100
GROUP BY senior_author_key
HAVING COUNT(*) > 1
ORDER BY n_papers DESC, total_citations DESC;
