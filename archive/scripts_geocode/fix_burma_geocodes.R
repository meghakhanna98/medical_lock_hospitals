library(DBI)
library(RSQLite)
library(dplyr)
library(httr)
library(jsonlite)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

normalize_burma_name <- function(n) {
  if (is.na(n) || n == "") return(NA_character_)
  n <- trimws(n)
  map <- c(
    "Rangoon" = "Yangon",
    "Moulmein" = "Mawlamyine",
    "Bassein" = "Pathein",
    "Akyab" = "Sittwe",
    "Prome" = "Pyay",
    "Tavoy" = "Dawei",
    "Mergui" = "Myeik",
    "Toungoo" = "Taungoo",
    "Thayetmyo" = "Thayet"
  )
  if (n %in% names(map)) return(map[[n]])
  n
}

geocode_mm <- function(query) {
  base <- 'https://nominatim.openstreetmap.org/search'
  url <- httr::modify_url(base, query = list(format = 'json', q = query, limit = 1, countrycodes = 'mm'))
  ua <- httr::user_agent('medical-lock-hospitals/1.1 (contact: example@example.com)')
  res <- tryCatch(httr::GET(url, ua, timeout(12)), error = function(e) NULL)
  if (is.null(res) || httr::status_code(res) != 200) return(NULL)
  body <- httr::content(res, as = 'text', encoding = 'UTF-8')
  js <- jsonlite::fromJSON(body)
  if (is.data.frame(js) && nrow(js) > 0) return(list(lat = as.numeric(js$lat[1]), lon = as.numeric(js$lon[1])))
  if (length(js) > 0 && !is.null(js[[1]]$lat)) return(list(lat = as.numeric(js[[1]]$lat), lon = as.numeric(js[[1]]$lon)))
  NULL
}

on.exit(dbDisconnect(conn), add = TRUE)

stations <- dbGetQuery(conn, "SELECT station_id, name, region, country, latitude, longitude FROM stations")

is_burma_region <- function(r) { grepl('burma', r, ignore.case = TRUE) }

suspect <- stations %>% mutate(
  lat = suppressWarnings(as.numeric(latitude)),
  lon = suppressWarnings(as.numeric(longitude))
) %>% filter(is_burma_region(region))

# Keep those with missing coords OR outside Myanmar bbox
in_mm_bbox <- function(lat, lon) !is.na(lat) && !is.na(lon) && lat >= 9 && lat <= 29 && lon >= 92 && lon <= 101
suspect <- suspect %>% filter(is.na(lat) | is.na(lon) | !mapply(in_mm_bbox, lat, lon))

if (nrow(suspect) == 0) {
  cat('No Burma-related suspect records found to fix.\n')
  quit(save = 'no')
}

cat('Fixing', nrow(suspect), 'Burma-related geocodes...\n')

updates <- list()
for (i in seq_len(nrow(suspect))) {
  nm <- suspect$name[i]
  nm_mm <- normalize_burma_name(nm)
  q <- paste(nm_mm, 'Myanmar')
  Sys.sleep(1)
  geo <- geocode_mm(q)
  if (!is.null(geo)) {
    updates[[length(updates) + 1]] <- list(id = suspect$station_id[i], lat = geo$lat, lon = geo$lon, name = nm, query = q)
    cat('Geocoded (MM):', nm, '->', nm_mm, '=>', geo$lat, geo$lon, '\n')
  } else {
    cat('No MM result for:', nm, '\n')
  }
}

if (length(updates) > 0) {
  for (u in updates) {
    dbExecute(conn, 'UPDATE stations SET latitude = ?, longitude = ? WHERE station_id = ?', params = list(u$lat, u$lon, u$id))
  }
  updated <- dbGetQuery(conn, 'SELECT * FROM stations')
  write.csv(updated, paste0('stations_after_fix_burma_', Sys.Date(), '.csv'), row.names = FALSE)
  cat('Updated', length(updates), 'stations (Burma fixes).\n')
} else {
  cat('No Burma fixes applied.\n')
}
