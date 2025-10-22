library(readxl)
library(DBI)
library(RSQLite)

# Excel file path
excel_file <- "/Users/meghakhanna/Desktop/Primary Sources/DS_Dataset.xlsx"

# Connect to SQLite database
conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

tryCatch({
  # Read women admission data
  women_df <- read_excel(excel_file, sheet = "women_admission")
  dbWriteTable(conn, "women_admission", women_df, overwrite = TRUE)
  cat(sprintf("Successfully imported %d rows into women_admission table\n", nrow(women_df)))

  # Read troops data
  troops_df <- read_excel(excel_file, sheet = "troops_admission")
  dbWriteTable(conn, "troops", troops_df, overwrite = TRUE)
  cat(sprintf("Successfully imported %d rows into troops table\n", nrow(troops_df)))

}, error = function(e) {
  cat("Error occurred:", conditionMessage(e), "\n")
}, finally = {
  dbDisconnect(conn)
})