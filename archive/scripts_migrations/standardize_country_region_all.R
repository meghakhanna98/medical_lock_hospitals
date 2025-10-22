library(DBI)
library(RSQLite)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

has_col <- function(tbl, col) {
  cols <- dbGetQuery(conn, sprintf("PRAGMA table_info(%s)", tbl))
  col %in% cols$name
}

backup_table <- function(tbl) {
  df <- dbGetQuery(conn, sprintf("SELECT * FROM %s", tbl))
  fn <- sprintf('%s_backup_before_standardize_%s.csv', tbl, Sys.Date())
  write.csv(df, fn, row.names = FALSE)
  cat('Backup written:', fn, '\n')
}

std_country <- function(tbl) {
  cat('\n===', tbl, '— standardizing country ===\n')
  backup_table(tbl)
  dbExecute(conn, sprintf("UPDATE %s SET country = 'British Burma' WHERE country IS NOT NULL AND TRIM(LOWER(country)) LIKE '%%burma%%'", tbl))
  dbExecute(conn, sprintf("UPDATE %s SET country = 'British India' WHERE country IS NOT NULL AND TRIM(country) <> '' AND TRIM(LOWER(country)) NOT LIKE '%%burma%%'", tbl))
}

std_region <- function(tbl) {
  cat('\n===', tbl, '— standardizing region ===\n')
  dbExecute(conn, sprintf("UPDATE %s SET region = 'British Burma Division' WHERE region IS NOT NULL AND TRIM(LOWER(region)) LIKE '%%burma%%'", tbl))
}

tryCatch({
  tables <- dbGetQuery(conn, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name
  # Exclude backup tables created earlier
  tables <- tables[!grepl('backup', tables, ignore.case = TRUE)]

  for (t in tables) {
    cat('\n>>> Checking table:', t, '\n')
    if (has_col(t, 'country')) std_country(t)
    if (has_col(t, 'region')) std_region(t)
  }
  cat('\nStandardization complete for all applicable tables.\n')
}, error = function(e) {
  cat('Error:', conditionMessage(e), '\n')
}, finally = {
  dbDisconnect(conn)
})
