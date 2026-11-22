# =============================================================================
# ThinkNeuro Bibliometrics - ETL pipeline in R + SQL
# -----------------------------------------------------------------------------
# Question: which research on sleep deprivation, learning and decision-making
#           is most influential, and how has it changed over time?
#
# E  EXTRACT   : read the raw Web of Science export (200 papers)           [R]
# T  TRANSFORM : clean + standardize text fields                           [R]
#                validate, find duplicates, deduplicate                    [SQL]
#                select the Top 100 most-cited papers                      [SQL]
#                split multi-value cells (affiliations, keywords)          [R]
#                summarize trends for the charts                           [SQL]
# L  LOAD      : save clean tables to SQLite, CSV and Excel                [R]
#
# How to run (from the repo folder):
#   Rscript pipeline.R
# =============================================================================

suppressPackageStartupMessages({
  library(readr)    # read CSV files
  library(dplyr)    # data cleaning verbs: mutate, filter, select...
  library(stringr)  # text cleaning: str_squish, str_split, str_detect...
  library(DBI)      # talk to a database from R
  library(RSQLite)  # SQLite = a small database stored in one file
  library(writexl)  # write Excel files
})

# ---- File locations ---------------------------------------------------------
# Find the folder this script lives in, so it works no matter where you run it.
args         <- commandArgs(trailingOnly = FALSE)
script_path  <- sub("^--file=", "", args[grep("^--file=", args)])
pipeline_dir <- if (length(script_path) == 1) dirname(normalizePath(script_path)) else getwd()

raw_csv <- file.path(pipeline_dir, "data", "savedrecs.csv")   # Web of Science export (not in repo)
if (!file.exists(raw_csv)) stop("Put the Web of Science export at data/savedrecs.csv (see README).")
sql_dir <- file.path(pipeline_dir, "sql")
out_dir <- file.path(pipeline_dir, "output")
dir.create(out_dir, showWarnings = FALSE)

# Helper: read a .sql file and return its text.
read_sql <- function(name) read_file(file.path(sql_dir, name))

# Helper: print a section header so the console output is easy to follow.
step <- function(title) cat("\n==========", title, "==========\n")


# =============================================================================
# STEP 1 - EXTRACT (R): read the raw export
# =============================================================================
step("STEP 1: EXTRACT")

raw <- read_csv(raw_csv,
                col_types   = cols(.default = col_character()),  # read all as text first,
                locale      = locale(encoding = "UTF-8"),         # convert types ourselves later
                name_repair = "unique_quiet")                     # repeated column names get a suffix

cat("Rows read:", nrow(raw), "| Columns read:", ncol(raw), "\n")

# Profile the raw columns: which ones are completely empty?
is_empty   <- sapply(raw, function(col) all(is.na(col) | str_trim(col) == ""))
empty_cols <- names(raw)[is_empty]
cat("Columns that are 100% empty (not used):", length(empty_cols), "\n")
cat("  e.g.", paste(head(empty_cols, 5), collapse = " | "), "\n")

# Repeated / unnamed helper columns (e.g. a second 'Times Cited, WoS Core'
# copied next to the authors so the old spreadsheet query could sort on it).
helper_cols <- names(raw)[str_detect(names(raw), "\\.\\.\\.\\d+$")]
cat("Repeated / unnamed helper columns:", paste(helper_cols, collapse = " | "), "\n")


# =============================================================================
# STEP 2 - TRANSFORM part 1 (R): clean + standardize
# =============================================================================
step("STEP 2: CLEAN + STANDARDIZE (R)")

# Keep only the columns we need, with short consistent names.
times_cited_col <- names(raw)[str_detect(names(raw), "^Times Cited, WoS Core")][1]

papers <- tibble(
  row_id          = seq_len(nrow(raw)),        # original order in the file
  ut              = raw$`UT (Unique WOS ID)`,  # Web of Science unique ID
  doi             = raw$DOI,
  title           = raw$`Article Title`,
  authors         = raw$Authors,
  journal         = raw$`Source Title`,
  pub_year        = raw$`Publication Year`,
  times_cited     = raw[[times_cited_col]],
  doc_type        = raw$`Document Type`,
  author_keywords = raw$`Author Keywords`,
  affiliations    = raw$Affiliations
)

papers <- papers %>%
  mutate(
    # 1) Trim extra spaces; turn empty strings into real missing values (NA)
    across(where(is.character), ~ na_if(str_squish(.x), "")),

    # 2) Convert number columns from text to integers
    pub_year    = as.integer(pub_year),
    times_cited = as.integer(times_cited),

    # 3) Standardize formats
    doi       = str_to_lower(doi),     # DOIs are case-insensitive
    journal   = str_to_upper(journal), # one consistent case
    title_key = str_squish(str_to_lower(str_replace_all(title, "[^[:alnum:] ]", " "))),  # for duplicate checks

    # 4) Split the author list "A; B; C" into useful fields
    n_authors         = str_count(authors, ";") + 1L,
    first_author      = str_trim(str_extract(authors, "^[^;]+")),  # before the first ;
    senior_author     = str_trim(str_extract(authors, "[^;]+$")),  # after the last ;
    senior_author_key = str_to_lower(senior_author)                 # for matching names
  )

cat("Cleaned rows:", nrow(papers), "\n")
print(head(select(papers, first_author, senior_author, pub_year, times_cited), 3))


# ---- Load the cleaned table into SQLite so we can work on it with SQL -------
db_path <- file.path(out_dir, "bibliometrics.sqlite")
if (file.exists(db_path)) invisible(file.remove(db_path))   # start fresh every run
con <- dbConnect(SQLite(), db_path)
dbWriteTable(con, "papers", papers)
cat("\nLoaded table 'papers' into SQLite:",
    dbGetQuery(con, "SELECT COUNT(*) AS n FROM papers")$n, "rows\n")


# =============================================================================
# STEP 3 - TRANSFORM part 2 (SQL): validate + deduplicate
# =============================================================================
step("STEP 3a: VALIDATION CHECKS (SQL)")
validation <- dbGetQuery(con, read_sql("01_validation_checks.sql"))
print(validation, row.names = FALSE)

step("STEP 3b: FIND DUPLICATES (SQL)")
duplicates <- dbGetQuery(con, read_sql("02_find_duplicates.sql"))
if (nrow(duplicates) == 0) {
  cat("No duplicates found on Web of Science ID, DOI, or title.\n")
} else {
  print(duplicates, row.names = FALSE)
}

step("STEP 3c: DEDUPLICATE (SQL)")
invisible(dbExecute(con, read_sql("03_deduplicate.sql")))
n_before <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM papers")$n
n_after  <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM papers_dedup")$n
cat("Rows before:", n_before, "| after:", n_after, "| removed:", n_before - n_after, "\n")


# =============================================================================
# STEP 4 - TRANSFORM part 3 (SQL): Top 100 most-cited papers
# =============================================================================
step("STEP 4: TOP 100 (SQL)")
invisible(dbExecute(con, read_sql("04_top100.sql")))
top100 <- dbGetQuery(con, "SELECT * FROM top100")
cat("Top-100 rows:", nrow(top100),
    "| citations range:", min(top100$times_cited), "to", max(top100$times_cited), "\n")

# Final sanity checks - the pipeline STOPS if any of these fail.
stopifnot(
  nrow(top100) == 100,                # exactly 100 papers
  !any(duplicated(top100$ut)),        # no duplicate papers
  !any(is.na(top100$times_cited)),    # every paper has a citation count
  all(diff(top100$times_cited) <= 0)  # sorted highest -> lowest
)
cat("Sanity checks passed.\n")


# =============================================================================
# STEP 5 - TRANSFORM part 4 (R): split multi-value cells + tag keywords
# =============================================================================
step("STEP 5: SPLIT AFFILIATIONS + TAG KEYWORDS (R)")

# Affiliations look like "Univ A; Univ B; Univ C" in ONE cell.
# To count institutions we need ONE ROW per (paper, institution) = "long" format.
aff_list <- str_split(top100$affiliations, ";")
top100_affiliations <- tibble(
  ut          = rep(top100$ut, lengths(aff_list)),
  institution = str_squish(unlist(aff_list))
) %>%
  filter(!is.na(institution), institution != "", institution != "NA") %>%
  distinct()                                   # one row per paper-institution pair
cat("Affiliation rows after splitting:", nrow(top100_affiliations), "\n")

# Tag each paper with ONE keyword theme, using the same priority rule as the
# original spreadsheet (sleep > decision > reinforcement > adolescent).
top100_keywords <- top100 %>%
  transmute(
    ut,
    kw = str_to_lower(author_keywords),
    keyword_category = case_when(
      is.na(kw)                          ~ "No author keywords",
      str_detect(kw, "sleep")            ~ "Sleep",
      str_detect(kw, "decision")         ~ "Decision-Making",
      str_detect(kw, "reinforcement")    ~ "Reinforcement Learning",
      str_detect(kw, "adolescen")        ~ "Adolescent",
      TRUE                               ~ "Other"
    )
  ) %>%
  select(-kw)

dbWriteTable(con, "top100_affiliations", top100_affiliations)
dbWriteTable(con, "top100_keywords",     top100_keywords)


# =============================================================================
# STEP 6 - ANALYZE (SQL): summary tables behind each chart
# =============================================================================
step("STEP 6: SUMMARY TABLES (SQL)")

by_year        <- dbGetQuery(con, read_sql("05_papers_by_year.sql"))
top_journals   <- dbGetQuery(con, read_sql("06_top_journals.sql"))
top_seniors    <- dbGetQuery(con, read_sql("07_top_senior_authors.sql"))
top_insts      <- dbGetQuery(con, read_sql("08_top_institutions.sql"))
keyword_themes <- dbGetQuery(con, read_sql("09_keyword_categories.sql"))

cat("\nTop-100 papers by year:\n");                 print(by_year, row.names = FALSE)
cat("\nJournals with >1 Top-100 paper:\n");         print(head(top_journals, 10), row.names = FALSE)
cat("\nSenior authors with >1 Top-100 paper:\n");   print(top_seniors, row.names = FALSE)
cat("\nInstitutions with >1 Top-100 paper (top 10):\n"); print(head(top_insts, 10), row.names = FALSE)
cat("\nKeyword themes:\n");                         print(keyword_themes, row.names = FALSE)

# Key numbers for the story
n_2018_2021 <- sum(by_year$n_papers[by_year$pub_year >= 2018 & by_year$pub_year <= 2021])
n_after2016 <- sum(by_year$n_papers[by_year$pub_year > 2016])
cat("\nKEY FINDING: ", n_2018_2021, " of the Top 100 were published 2018-2021; ",
    n_after2016, " were published after 2016.\n", sep = "")


# =============================================================================
# STEP 7 - LOAD (R): save outputs
# =============================================================================
step("STEP 7: LOAD / SAVE OUTPUTS")

write_csv(top100, file.path(out_dir, "top100_clean.csv"), na = "")

write_xlsx(
  list(
    "Top100 Clean"        = top100,
    "Validation Checks"   = validation,
    "Papers by Year"      = by_year,
    "Top Journals"        = top_journals,
    "Top Senior Authors"  = top_seniors,
    "Top Institutions"    = top_insts,
    "Keyword Themes"      = keyword_themes
  ),
  file.path(out_dir, "thinkneuro_results.xlsx")
)

dbDisconnect(con)
cat("Saved to:", out_dir, "\n")
cat("  - bibliometrics.sqlite    (database: papers, papers_dedup, top100, ...)\n")
cat("  - top100_clean.csv        (the analysis-ready dataset)\n")
cat("  - thinkneuro_results.xlsx (one sheet per table, ready for Excel charts)\n")
cat("\nPipeline finished.\n")
