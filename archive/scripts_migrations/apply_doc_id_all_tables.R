library(DBI)
library(RSQLite)
library(dplyr)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

region_codes <- list(
  "madras" = "MD", "madras presidency" = "MD",
  "burma" = "BB",
  "central provinces" = "CP", "central" = "CP",
  "north-western provinces and oudh" = "NWPO",
  "north-western provinces" = "NWPO", "north-we" = "NWPO",
  "punjab" = "PB"
)

generate_doc_id <- function(region, year) {
  if (is.na(region) || is.na(year)) return(NA)
  region_lower <- tolower(trimws(region))
  code <- region_codes[[region_lower]]
  if (is.null(code)) {
    for (name in names(region_codes)) {
      if (grepl(name, region_lower, fixed = TRUE) || grepl(region_lower, name, fixed = TRUE)) {
        code <- region_codes[[name]]
        break
      }
    }
    if (is.null(code)) code <- toupper(substr(region, 1, 2))
  }
  paste0(code, as.integer(year))
}

update_table <- function(table_name, region_col, year_col, id_col) {
  cat("\n=== Processing", table_name, "===\n")
  
  df <- dbGetQuery(conn, sprintf("SELECT * FROM %s", table_name))
  
  if (!region_col %in% names(df) || !year_col %in% names(df)) {
    cat("Skipping - missing required columns\n")
    return(0)
  }
  
  backup_file <- sprintf('%s_backup_%s.csv', table_name, Sys.Date())
  write.csv(df, backup_file, row.names = FALSE)
  cat("Backup:", backup_file, "\n")
  
  df$new_doc_id <- mapply(generate_doc_id, df[[region_col]], df[[year_col]])
  changes <- which(!is.na(df$new_doc_id) & df$doc_id != df$new_doc_id)
  
  if (length(changes) == 0) {
    cat("No changes needed\n")
    return(0)
  }
  
  df_changes <- df[changes, ]
  
  for (i in seq_len(nrow(df_changes))) {
    new_id <- df_changes$new_doc_id[i]
    row_id <- df_changes[[id_col]][i]
    dbExecute(conn, sprintf("UPDATE %s SET doc_id = ? WHERE %s = ?", table_name, id_col),
              params = list(new_id, row_id))
  }
  
  changes_file <- sprintf('%s_docid_changes_%s.csv', table_name, Sys.Date())
  write.csv(df_changes, changes_file, row.names = FALSE)
  cat("Updated:", nrow(df_changes), "rows\n")
  cat("Details:", changes_file, "\n")
  
  return(nrow(df_changes))
}

tryCatch({
  total <- 0
  
  cat("\n=== hospital_notes ===\n")
  cat("Skipping - no region column\n")
  
  cat("\n=== documents ===\n")
  cat("Skipping - no region/year columns\n")
  
  total <- total + update_table("women_admission", "region", "year", "unique_id")
  total <- total + update_table("troops", "region", "year", "unique_id")
  
  cat("\n=== station_reports ===\n")
  sr_cols <- dbGetQuery(conn, "PRAGMA table_info(station_reports)")
  if ("region" %in% sr_cols$name && "year" %in% sr_cols$name) {
    total <- total + update_table("station_reports", "region", "year", "report_id")
  } else {
    cat("Skipping - missing region/year columns\n")
  }
  
  cat("\n=== stations ===\n")
  cat("Skipping - no doc_id column\n")
  
  cat("\n=== SUMMARY ===\n")
  cat("Total rows updated:", total, "\n")
  
}, error = function(e) {
  cat("Error:", conditionMessage(e), "\n")
}, finally = {
  dbDisconnect(conn)
})
