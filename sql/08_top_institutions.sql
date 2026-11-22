-- STEP 6d: Institutions that appear on more than one Top-100 paper
-- (Excel chart: "Institutions with Multiple Top-100 Papers")
-- top100_affiliations has ONE ROW PER (paper, institution) - R split the
-- semicolon-separated cell into separate rows before loading it here.
-- COUNT(DISTINCT ut) makes sure one paper is only counted once per institution.

SELECT institution,
       COUNT(DISTINCT ut) AS n_papers
FROM top100_affiliations
GROUP BY institution
HAVING COUNT(DISTINCT ut) > 1
ORDER BY n_papers DESC, institution;
