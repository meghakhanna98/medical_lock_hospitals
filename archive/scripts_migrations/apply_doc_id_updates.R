library(DBI)
library(RSQLite)
library(dplyr)

# Backup and apply doc_id updates safely
conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

region_codes <- list(
  "madras" = "MD",
  "burma" = "BB",
  "central provinces" = "CP",
  "central" = "CP",
  "north-western provinces and oudh" = "NWPO",
  "north-western provinces" = "NWPO",
  "north-we" = "NWPO",
  "punjab" = "PB"
)

generate_doc_id <- function(region, year) {
  region_lower <- tolower(region)
  code <- region_codes[[region_lower]]
  if (is.null(code)) {
    for (name in names(region_codes)) {
      if (grepl(name, region_lower) || grepl(region_lower, name)) {
        code <- region_codes[[name]]
        break
      }
    }
    if (is.null(code)) code <- toupper(substr(region, 1, 2))
  }
  paste0(code, year)
}

tryCatch({
  df <- dbGetQuery(conn, "SELECT * FROM hospital_operations")
  backup_file <- paste0('hospital_operations_backup_', Sys.Date(), '.csv')
  write.csv(df, backup_file, row.names = FALSE)
  cat('Backup written to', backup_file, '\n')

  # Compute new doc_ids
  df_changes <- df %>% mutate(new_doc_id = mapply(generate_doc_id, region, year)) %>%
    filter(doc_id != new_doc_id)

  if (nrow(df_changes) == 0) {
    cat('No changes to apply.\n')
  } else {
    # Apply changes
    for (i in seq_len(nrow(df_changes))) {
      old <- df_changes$doc_id[i]
      new <- df_changes$new_doc_id[i]
      rowid <- df_changes$hid[i]
      dbExecute(conn, 'UPDATE hospital_operations SET doc_id = ? WHERE hid = ?', params = list(new, rowid))
    }

    changed_file <- paste0('hospital_operations_docid_changes_', Sys.Date(), '.csv')
    write.csv(df_changes, changed_file, row.names = FALSE)
    cat('Applied', nrow(df_changes), 'doc_id updates. Details in', changed_file, '\n')
  }
}, error = function(e) {
  cat('Error:', conditionMessage(e), '\n')
}, finally = {
  dbDisconnect(conn)
})
