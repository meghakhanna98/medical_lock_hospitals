library(DBI)
library(RSQLite)
library(dplyr)
library(readr)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

normalize_country <- function(country) {
  if (is.na(country) || country == "") return(NA_character_)
  country <- trimws(country)
  if (grepl("burma", country, ignore.case = TRUE)) return("Myanmar")
  if (grepl("british india", country, ignore.case = TRUE) || grepl("india", country, ignore.case = TRUE)) return("India")
  country
}

in_bbox <- function(lat, lon, country_norm) {
  if (is.na(lat) || is.na(lon) || is.na(country_norm)) return(NA)
  if (country_norm == "Myanmar") {
    return(lat >= 9 & lat <= 29 & lon >= 92 & lon <= 101)
  }
  if (country_norm == "India") {
    # Allow IN/PK/BD bbox combined
    in_in <- lat >= 6 & lat <= 36 & lon >= 68 & lon <= 97
    in_pk <- lat >= 23 & lat <= 38 & lon >= 60 & lon <= 78
    in_bd <- lat >= 20 & lat <= 27 & lon >= 88 & lon <= 93
    return(in_in | in_pk | in_bd)
  }
  NA
}

on.exit(dbDisconnect(conn), add = TRUE)

stations <- dbGetQuery(conn, "SELECT station_id, name, region, country, latitude, longitude FROM stations")

stations <- stations %>% mutate(
  latitude = suppressWarnings(as.numeric(latitude)),
  longitude = suppressWarnings(as.numeric(longitude)),
  country_norm = vapply(country, normalize_country, character(1)),
  in_expected_bbox = mapply(in_bbox, latitude, longitude, country_norm),
  region_mentions_burma = grepl("burma", region, ignore.case = TRUE),
  in_myanmar_bbox = mapply(in_bbox, latitude, longitude, rep("Myanmar", length.out = n()))
)

# Additional suspect rules:
# - Region mentions Burma but country_norm is India
# - Region mentions Burma but coordinates not in Myanmar bbox
suspect <- stations %>%
  mutate(
    reason_outside_bbox = ifelse(!is.na(latitude) & !is.na(longitude) & (is.na(in_expected_bbox) | !in_expected_bbox), TRUE, FALSE),
    reason_burma_country_mismatch = ifelse(region_mentions_burma & country_norm == "India", TRUE, FALSE),
    reason_burma_not_in_mm = ifelse(region_mentions_burma & (!is.na(latitude) & !is.na(longitude)) & !in_myanmar_bbox, TRUE, FALSE)
  ) %>%
  filter(reason_outside_bbox | reason_burma_country_mismatch | reason_burma_not_in_mm)

write_csv(stations, "geocode_audit_full.csv")
write_csv(suspect, "geocode_audit_suspect.csv")

sus_outside <- sum(suspect$reason_outside_bbox, na.rm = TRUE)
sus_burma_mismatch <- sum(suspect$reason_burma_country_mismatch, na.rm = TRUE)
sus_burma_not_mm <- sum(suspect$reason_burma_not_in_mm, na.rm = TRUE)

cat("Audit complete. Total stations:", nrow(stations), "\n")
cat("With coordinates:", sum(!is.na(stations$latitude) & !is.na(stations$longitude)), "\n")
cat("Suspect total:", nrow(suspect), " (outside bbox:", sus_outside, ", burma country mismatch:", sus_burma_mismatch, ", burma not in MM bbox:", sus_burma_not_mm, ")\n", sep = "")
