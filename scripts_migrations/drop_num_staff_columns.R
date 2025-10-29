#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

message("Dropping *_num staff columns from hospital_operations if present…")

db_path <- file.path(getwd(), "medical_lock_hospitals.db")
if (!file.exists(db_path)) {
  stop("Database not found at ", db_path)
}

# Ensure backup directory exists
backup_dir <- file.path(getwd(), "archive", "backups")
if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE)

# Create a timestamped backup
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
backup_path <- file.path(backup_dir, paste0("medical_lock_hospitals.db.drop_num_cols_", stamp, ".bak"))
file.copy(db_path, backup_path, overwrite = TRUE)
message("Backup created: ", backup_path)

con <- dbConnect(RSQLite::SQLite(), db_path)
on.exit({ try(dbDisconnect(con), silent = TRUE) }, add = TRUE)

cols <- dbGetQuery(con, "PRAGMA table_info(hospital_operations);")
if (nrow(cols) == 0) stop("Table hospital_operations not found in DB")

candidates <- c(
  "staff_medical_officers_num","staff_hospital_assistants_num","staff_matron_num",
  "staff_coolies_num","staff_peons_num","staff_watermen_num","staff_total_num"
)

present <- intersect(candidates, cols$name)
if (length(present) == 0) {
  message("No *_num columns present. Nothing to do.")
  quit(save = "no", status = 0)
}

message("Columns to drop: ", paste(present, collapse = ", "))

# Try native DROP COLUMN first (SQLite >= 3.35)
remaining <- present
for (cn in present) {
  ok <- try({
    dbExecute(con, sprintf("ALTER TABLE hospital_operations DROP COLUMN %s", DBI::dbQuoteIdentifier(con, cn)))
  }, silent = TRUE)
  if (!inherits(ok, "try-error")) {
    message("Dropped column via ALTER TABLE DROP COLUMN: ", cn)
  } else {
    message("Could not drop directly: ", cn)
  }
}

# Recheck remaining columns
cols_after <- dbGetQuery(con, "PRAGMA table_info(hospital_operations);")
remaining <- intersect(candidates, cols_after$name)

if (length(remaining) == 0) {
  message("All *_num columns removed using native DROP COLUMN.")
  quit(save = "no", status = 0)
}

message("Falling back to table rebuild for: ", paste(remaining, collapse = ", "))

# Rebuild table without remaining columns
DBI::dbExecute(con, "ALTER TABLE hospital_operations RENAME TO hospital_operations_tmp")
cols_tmp <- dbGetQuery(con, "PRAGMA table_info(hospital_operations_tmp);")
keep <- setdiff(cols_tmp$name, candidates)
if (length(keep) == 0) stop("No columns left to keep after dropping; aborting.")

# Create new table as SELECT of kept columns
create_sql <- sprintf(
  "CREATE TABLE hospital_operations AS SELECT %s FROM hospital_operations_tmp",
  paste(sprintf("%s", DBI::dbQuoteIdentifier(con, keep)), collapse = ", ")
)
DBI::dbExecute(con, create_sql)
DBI::dbExecute(con, "DROP TABLE hospital_operations_tmp")

message("Rebuild complete. Current columns: ", paste(dbGetQuery(con, "PRAGMA table_info(hospital_operations);")$name, collapse = ", "))
message("Done.")
