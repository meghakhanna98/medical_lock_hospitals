library(DBI)
library(RSQLite)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")
on.exit(dbDisconnect(conn), add = TRUE)

# Backup stations before change
stations <- dbGetQuery(conn, "SELECT * FROM stations")
write.csv(stations, paste0("stations_backup_before_set_burma_", Sys.Date(), ".csv"), row.names = FALSE)

# Update country to 'British Burma' where region mentions 'Burma'
updated <- dbExecute(conn, "UPDATE stations SET country = 'British Burma' WHERE lower(region) LIKE '%burma%'")

cat("Rows updated:", updated, "\n")

# Show a quick sample of affected rows
sample <- dbGetQuery(conn, "SELECT station_id, name, region, country FROM stations WHERE lower(region) LIKE '%burma%' ORDER BY name LIMIT 20")
print(sample)
