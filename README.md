# ThinkNeuro Bibliometrics: R & SQL ETL Pipeline

An ETL pipeline that turns a raw Web of Science export of **200 neuroscience papers** on sleep deprivation, learning and decision-making into a **validated Top-100 dataset**, then summarizes citation trends for charting in Excel.

Built for the **ThinkNeuro Bibliometrics Research Internship** (Research Data Analyst Intern, Sep–Dec 2025). The findings were presented on a research poster, included in this repo.

## Key results

| Result | Value | Source |
|---|---|---|
| Papers in → papers out | **200 → 100** | Pipeline |
| Top-100 papers published after 2016 | **85%** (85 of 100) | Pipeline, `05_papers_by_year.sql` |
| Top-100 papers published 2018–2021 | **68** | Pipeline |
| Duplicates found (by Web of Science ID, DOI, title) | **0** | Pipeline, `02_find_duplicates.sql` |
| Records missing DOI / author keywords / affiliations | **3 / 16 / 4** | Pipeline, `01_validation_checks.sql` |
| Empty columns in raw export | **35 of 75** | Pipeline, Step 1 profiling |
| Leading journal | ***SLEEP*, 13 papers** | Pipeline, `06_top_journals.sql` |
| Accuracy drop, sleep-deprived vs. rested participants | **~15 vs. ~3.5 points** (A/not-A task, Day 1 → Day 2) | Re-plotted in Excel from the key study, [Maddox et al., 2011](https://doi.org/10.1093/sleep/34.3.253). *Not computed by this pipeline.* |

## Data flow

```
Web of Science export (CSV, 200 papers × 75 columns)
        │
        ▼
[R]   EXTRACT    read CSV, profile empty / repeated columns
[R]   TRANSFORM  trim + standardize text, extract first & senior author
        │
        ▼  load into SQLite
[SQL] TRANSFORM  validation checks → find duplicates → deduplicate → Top 100
        │
        ▼
[R]   TRANSFORM  split multi-value cells (affiliations, keywords) into rows
[SQL] ANALYZE    papers by year, top journals, senior authors, institutions
        │
        ▼
[R]   LOAD       write SQLite DB, clean CSV, and Excel workbook → charts → poster
```

## Why R and SQL

| | R | SQL (SQLite) |
|---|---|---|
| Used for | Messy text and reshaping | Checking, filtering, ranking, summarizing |
| Steps | Read CSV · trim/standardize text · extract authors · split affiliations into rows · tag keyword themes · export | Count missing/invalid values · `GROUP BY … HAVING` duplicate checks · `ROW_NUMBER()` deduplication · `ORDER BY … LIMIT 100` Top-100 · aggregate tables |

## Repository structure

```
pipeline.R                      main script: runs every step in order
sql/
  01_validation_checks.sql      missing / out-of-range values per check
  02_find_duplicates.sql        repeated IDs, DOIs, titles
  03_deduplicate.sql            keep one row per Web of Science ID (window function)
  04_top100.sql                 rank by citations, keep Top 100
  05_papers_by_year.sql         trend over time
  06_top_journals.sql           journals with >1 Top-100 paper
  07_top_senior_authors.sql     senior (last) authors with >1 Top-100 paper
  08_top_institutions.sql       institutions with >1 Top-100 paper
  09_keyword_categories.sql     keyword themes
Group 6 Cognitive Comp Research Poster.pdf
#6 Cognitive-and-Comp Abstract.pdf
```

## How to run

Requires R (4.x) and these packages:

```r
install.packages(c("DBI", "RSQLite", "dplyr", "stringr", "readr", "writexl"))
```

1. Export records from Web of Science (Export → Excel/CSV, full record) and save the file as `data/savedrecs.csv`.
   The raw export is not included in this repo because Web of Science data is licensed.
2. From the repo folder, run:
   ```
   Rscript pipeline.R
   ```
3. Outputs are written to `output/`:
   - `bibliometrics.sqlite`: database with `papers`, `papers_dedup`, `top100` and summary tables
   - `top100_clean.csv`: the analysis-ready Top-100 dataset
   - `thinkneuro_results.xlsx`: one sheet per summary table, used for the Excel charts

The pipeline stops with an error if the final dataset fails its checks: not exactly 100 rows, duplicate IDs, missing citation counts, or wrong sort order.

## Limitations

- **Citation bias:** older papers have had more time to collect citations. A fairer ranking would normalize by years since publication.
- **Tie at the cutoff:** five papers have 14 citations for the 100th spot. The tie is broken by original file order, so results are reproducible.
- **Keyword themes:** each paper gets one theme, checked in the order sleep → decision → reinforcement → adolescent, so 88 of 100 land in "Sleep". Multi-label tagging would be more informative.
- **Key study sample:** the accuracy finding comes from young adults (West Point cadets). The poster's research question concerns adolescents.

## Note on this version

The original internship work combined spreadsheet formulas (including a Google Sheets `QUERY`, which uses SQL-style syntax, for the Top-100 selection) with R. After the original scripts were lost, I rebuilt the full pipeline in R and SQLite from the original Web of Science export, so every step is now scripted and reproducible. The rebuilt Top 100 matches the original on 99 of 100 papers. The one difference is a tie-break at the 14-citation cutoff.
