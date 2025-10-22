library(DBI)
library(RSQLite)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

tryCatch({
  # Remove link column from women_admission
  cat("Removing link column from women_admission...\n")
  
  # Backup first
  women_backup <- dbGetQuery(conn, "SELECT * FROM women_admission")
  write.csv(women_backup, paste0("women_admission_backup_before_link_removal_", Sys.Date(), ".csv"), row.names = FALSE)
  
  # Create new table without link column
  dbExecute(conn, "
    CREATE TABLE women_admission_new AS 
    SELECT unique_id, doc_id, source_name, source_type, region, station, country, year,
           women_start_register, women_added, women_removed, women_end_register, 
           avg_registered, non_attendance_cases, fined_count, imprisonment_count,
           disease_primary_syphilis, disease_secondary_syphilis, disease_gonorrhoea,
           disease_leucorrhoea, discharges, deaths, Total, side_notes
    FROM women_admission
  ")
  
  # Drop old table and rename new one
  dbExecute(conn, "DROP TABLE women_admission")
  dbExecute(conn, "ALTER TABLE women_admission_new RENAME TO women_admission")
  
  cat("Successfully removed link column from women_admission\n")
  
  # Remove link column from troops
  cat("\nRemoving link column from troops...\n")
  
  # Backup first
  troops_backup <- dbGetQuery(conn, "SELECT * FROM troops")
  write.csv(troops_backup, paste0("troops_backup_before_link_removal_", Sys.Date(), ".csv"), row.names = FALSE)
  
  # Create new table without link column
  dbExecute(conn, "
    CREATE TABLE troops_new AS 
    SELECT unique_id, doc_id, source_name, source_type, region, station, country, year,
           Regiments, avg_strength, primary_syphilis, secondary_syphilis, gonorrhoea,
           orchitis_gonorrhoea, phimosis, warts, total_admissions, contracted_elsewhere,
           contracted_at_station, ratio_per_1000, period_of_occupation
    FROM troops
  ")
  
  # Drop old table and rename new one
  dbExecute(conn, "DROP TABLE troops")
  dbExecute(conn, "ALTER TABLE troops_new RENAME TO troops")
  
  cat("Successfully removed link column from troops\n")
  
  cat("\nDone! Link columns removed from both tables.\n")
  
}, error = function(e) {
  cat("Error:", conditionMessage(e), "\n")
}, finally = {
  dbDisconnect(conn)
})
