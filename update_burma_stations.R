library(DBI)
library(RSQLite)

con <- dbConnect(RSQLite::SQLite(), 'medical_lock_hospitals.db')

cat("Merging Burma station data...\n")

# Update all references to 'India (British Burma)' to use 'Thayetmyo'
cat("Updating women_admission...\n")
dbExecute(con, "UPDATE women_admission SET station = 'Thayetmyo' WHERE station = 'India (British Burma)'")

cat("Updating troops...\n")
dbExecute(con, "UPDATE troops SET station = 'Thayetmyo' WHERE station = 'India (British Burma)'")

cat("Updating hospital_operations...\n")
dbExecute(con, "UPDATE hospital_operations SET station = 'Thayetmyo' WHERE station = 'India (British Burma)'")

# Update all references to 'India (British Burma)+G143' to use 'Tonghoo'
cat("Updating women_admission for Tonghoo...\n")
dbExecute(con, "UPDATE women_admission SET station = 'Tonghoo' WHERE station = 'India (British Burma)+G143' OR station = 'India (British Burma)+G143 Station'")

cat("Updating troops for Tonghoo...\n")
dbExecute(con, "UPDATE troops SET station = 'Tonghoo' WHERE station = 'India (British Burma)+G143' OR station = 'India (British Burma)+G143 Station'")

cat("Updating hospital_operations for Tonghoo...\n")
dbExecute(con, "UPDATE hospital_operations SET station = 'Tonghoo' WHERE station = 'India (British Burma)+G143' OR station = 'India (British Burma)+G143 Station'")

# Delete the duplicate station entries
cat("\nDeleting duplicate station entries...\n")
dbExecute(con, "DELETE FROM stations WHERE station_id = 3")
dbExecute(con, "DELETE FROM stations WHERE station_id = 361")

# Verify the changes
cat("\nRemaining Burma stations:\n")
print(dbGetQuery(con, "SELECT station_id, name, region, country FROM stations WHERE name IN ('Thayetmyo', 'Tonghoo')"))

cat("\nAll updates complete!\n")
dbDisconnect(con)
