library(DBI)
library(RSQLite)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

backup_table <- function(tbl) {
  df <- dbGetQuery(conn, sprintf("SELECT * FROM %s", tbl))
  fn <- sprintf('%s_backup_before_standardize_%s.csv', tbl, Sys.Date())
  write.csv(df, fn, row.names = FALSE)
  cat('Backup written:', fn, '\n')
}

std_country <- function(tbl) {
  cat('\n===', tbl, '— standardizing country ===\n')
  backup_table(tbl)
  # Set to British Burma when country mentions Burma; otherwise British India (for non-null rows)
  dbExecute(conn, sprintf("UPDATE %s SET country = 'British Burma' WHERE country IS NOT NULL AND TRIM(LOWER(country)) LIKE '%%burma%%'", tbl))
  dbExecute(conn, sprintf("UPDATE %s SET country = 'British India' WHERE country IS NOT NULL AND TRIM(country) <> '' AND TRIM(LOWER(country)) NOT LIKE '%%burma%%'", tbl))
}

std_region <- function(tbl) {
  cat('\n===', tbl, '— standardizing region ===\n')
  # Only change rows that mention Burma in region
  dbExecute(conn, sprintf("UPDATE %s SET region = 'British Burma Division' WHERE region IS NOT NULL AND TRIM(LOWER(region)) LIKE '%%burma%%'", tbl))
}

tryCatch({
  # hospital_operations
  std_country('hospital_operations')
  std_region('hospital_operations')

  # women_admission
  std_country('women_admission')
  std_region('women_admission')

  # troops
  std_country('troops')
  std_region('troops')

  # stations (has country/region columns, no doc_id)
  std_country('stations')
  std_region('stations')

  cat('\nStandardization complete.\n')
}, error = function(e) {
  cat('Error:', conditionMessage(e), '\n')
}, finally = {
  dbDisconnect(conn)
})
