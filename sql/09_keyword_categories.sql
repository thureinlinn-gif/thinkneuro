-- STEP 6e: How many Top-100 papers fall into each keyword theme?
-- (Excel sheet "fig 5")

SELECT keyword_category,
       COUNT(*) AS n_papers
FROM top100_keywords
GROUP BY keyword_category
ORDER BY n_papers DESC;
