-- STEP 6a: TREND - how many Top-100 papers were published each year?
-- (Poster Figure 5: "Distribution of Top 100 Cited Articles by Publication Year")

SELECT pub_year,
       COUNT(*)          AS n_papers,
       SUM(times_cited)  AS total_citations
FROM top100
GROUP BY pub_year
ORDER BY pub_year;
