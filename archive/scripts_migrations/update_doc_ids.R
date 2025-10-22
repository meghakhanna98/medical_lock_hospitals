library(DBI)
library(RSQLite)
library(dplyr)

# Connect to SQLite database
conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

# Function to generate new doc_id
generate_doc_id <- function(region, year) {
  # Define region code mappings
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
  
  # Convert region to lowercase for matching
  region_lower <- tolower(region)
  
  # Get region code (or keep original if not in mapping)
  code <- region_codes[[region_lower]]
  if (is.null(code)) {
    # Try partial matching for longer region names
    for (name in names(region_codes)) {
      if (grepl(name, region_lower) || grepl(region_lower, name)) {
        code <- region_codes[[name]]
        break
      }
    }
    # If still no match, use first two letters
    if (is.null(code)) {
      code <- toupper(substr(region, 1, 2))
    }
  }
  
  # Combine with year
  paste0(code, year)
}

tryCatch({
  # Get all records
  data <- dbGetQuery(conn, "SELECT doc_id, region, year FROM hospital_operations")
  
  # Preview changes
  changes <- data.frame(
    old_doc_id = character(0),
    new_doc_id = character(0),
    region = character(0),
    year = integer(0),
    stringsAsFactors = FALSE
  )
  
  # Generate preview of new doc_ids
  for (i in 1:nrow(data)) {
    old_doc_id <- data$doc_id[i]
    new_doc_id <- generate_doc_id(data$region[i], data$year[i])
    
    changes <- rbind(changes, data.frame(
      old_doc_id = old_doc_id,
      new_doc_id = new_doc_id,
      region = data$region[i],
      year = data$year[i],
      stringsAsFactors = FALSE
    ))
  }
  
  # Show preview
  cat("Preview of doc_id changes:\n")
  cat("----------------------------------------\n")
  cat("Region                | Year | Old ID -> New ID\n")
  cat("----------------------------------------\n")
  
  # Print unique combinations to avoid repetition
  unique_changes <- unique(changes)
  unique_changes <- unique_changes[order(unique_changes$region, unique_changes$year), ]
  
  for (i in 1:nrow(unique_changes)) {
    cat(sprintf("%-20s| %4d | %-15s -> %s\n",
               substr(unique_changes$region[i], 1, 20),
               unique_changes$year[i],
               unique_changes$old_doc_id[i],
               unique_changes$new_doc_id[i]))
  }
  
  cat("\nTotal records to update:", nrow(changes), "\n")
  cat("\nTo apply these changes, remove the preview code and uncomment the update code.\n")
  
}, error = function(e) {
  cat("Error occurred:", conditionMessage(e), "\n")
}, finally = {
  dbDisconnect(conn)
})