library(DBI)
library(RSQLite)
library(httr)
library(jsonlite)
library(dplyr)
library(stringr)

conn <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

# --- Normalization helpers ---
normalize_country <- function(country) {
  if (is.na(country) || country == "") return(NA_character_)
  country <- trimws(country)
  case_when(
    str_detect(country, regex("british india", ignore_case = TRUE)) ~ "India",
    str_detect(country, regex("burma", ignore_case = TRUE)) ~ "Myanmar",
    TRUE ~ country
  )
}

countrycodes_for <- function(country) {
  # Nominatim countrycodes: https://nominatim.org/release-docs/develop/api/Search/#parameters
  if (is.na(country) || country == "") return(NA_character_)
  if (country == "India") return("in,pk,bd") # historical British India spans present IN/PK/BD
  if (country == "Myanmar") return("mm")
  # Fallback: try a few likely South Asia codes
  return("in,pk,bd,mm")
}

normalize_region <- function(region) {
  if (is.na(region) || region == "") return(NA_character_)
  r <- trimws(region)
  # Very lightweight mapping for common colonial-to-modern regions
  mappings <- c(
    "Bombay" = "Maharashtra",
    "Bombay Presidency" = "Maharashtra",
    "Madras" = "Tamil Nadu",
    "Madras Presidency" = "Tamil Nadu",
    "Bengal" = "West Bengal",
    "North Western Provinces" = "Uttar Pradesh",
    "North Western Provinces and Oudh" = "Uttar Pradesh",
    "Oudh" = "Uttar Pradesh",
    "Punjab" = "Punjab",
    "Central Provinces" = "Madhya Pradesh",
    "Berar" = "Maharashtra"
  )
  if (r %in% names(mappings)) return(mappings[[r]])
  r
}

normalize_station_name <- function(name, country_norm) {
  if (is.na(name) || name == "") return(NA_character_)
  n <- trimws(name)
  # Common colonial -> modern city name mappings
  map_burma <- c(
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
  map_india <- c(
    "Calcutta" = "Kolkata",
    "Bombay" = "Mumbai",
    "Madras" = "Chennai",
    "Poona" = "Pune",
    "Cawnpore" = "Kanpur",
    "Benares" = "Varanasi",
    "Allahabad" = "Prayagraj",
    "Trichinopoly" = "Tiruchirappalli",
    "Baroda" = "Vadodara",
    "Ootacamund" = "Udhagamandalam",
    "Quilon" = "Kollam",
    "Trivandrum" = "Thiruvananthapuram",
    "Saugor" = "Sagar",
    "Vizagapatam" = "Visakhapatnam",
    "Cuddapah" = "Kadapa",
    "Bangalore" = "Bengaluru",
    "Mangalore" = "Mangaluru"
  )
  if (!is.na(country_norm) && country_norm == "Myanmar" && n %in% names(map_burma)) return(map_burma[[n]])
  if (!is.na(country_norm) && country_norm == "India" && n %in% names(map_india)) return(map_india[[n]])
  n
}

build_queries <- function(name, region, country) {
  ctry <- normalize_country(country)
  reg <- normalize_region(region)
  nm <- normalize_station_name(name, ctry)
  # Unique, non-empty strings only
  vals <- function(...) unique(na.omit(Filter(function(x) !is.na(x) && x != "", list(...))))
  # Progressive specificity: try with region+country, then country only, then name only
  q <- list(
    paste(vals(nm, reg, ctry), collapse = ", "),
    paste(vals(nm, ctry), collapse = ", "),
    nm
  )
  list(queries = q, countrycodes = countrycodes_for(ctry))
}

geocode_one <- function(query, countrycodes = NA_character_) {
  base <- 'https://nominatim.openstreetmap.org/search'
  params <- list(format = 'json', q = query, limit = 1)
  if (!is.na(countrycodes) && countrycodes != "") params$countrycodes <- countrycodes
  url <- modify_url(base, query = params)
  ua <- user_agent('medical-lock-hospitals/1.1 (contact: example@example.com)')
  res <- tryCatch(GET(url, ua, timeout(12)), error = function(e) NULL)
  if (is.null(res) || status_code(res) != 200) return(NULL)
  body <- content(res, as = 'text', encoding = 'UTF-8')
  js <- fromJSON(body)
  if (length(js) == 0) return(NULL)
  # js can be a data.frame with columns 'lat'/'lon' or a list of lists
  if (is.data.frame(js) && nrow(js) > 0) {
    return(list(lat = suppressWarnings(as.numeric(js$lat[1])),
                lon = suppressWarnings(as.numeric(js$lon[1]))))
  }
  if (is.list(js) && length(js) > 0 && !is.null(js[[1]]$lat)) {
    return(list(lat = suppressWarnings(as.numeric(js[[1]]$lat)),
                lon = suppressWarnings(as.numeric(js[[1]]$lon))))
  }
  return(NULL)
}

tryCatch({
  stations <- dbGetQuery(conn, "SELECT station_id, name, region, country, latitude, longitude FROM stations")
  # Backup current stations table
  write.csv(stations, paste0('stations_backup_before_geocode_', Sys.Date(), '.csv'), row.names = FALSE)

  missing <- stations %>% filter(is.na(latitude) | is.na(longitude) | latitude == '' | longitude == '')
  if (nrow(missing) == 0) {
    cat('No stations with missing coordinates.\n')
  } else {
    cat('Found', nrow(missing), 'stations to geocode...\n')
    updates <- list()
    for (i in seq_len(nrow(missing))) {
      nm <- missing$name[i]
      reg <- missing$region[i]
      ctry <- missing$country[i]
      bq <- build_queries(nm, reg, ctry)
      found <- NULL
      for (q in bq$queries) {
        if (is.na(q) || q == "") next
        Sys.sleep(1) # be polite to Nominatim
        geo <- geocode_one(q, countrycodes = bq$countrycodes)
        if (!is.null(geo)) { found <- geo; cat('Geocoded:', q, '->', geo$lat, geo$lon, '\n'); break }
        else { cat('No result for:', q, '\n') }
      }
      if (!is.null(found)) {
        updates[[length(updates) + 1]] <- list(id = missing$station_id[i], lat = found$lat, lon = found$lon)
      }
    }
    if (length(updates) > 0) {
      for (u in updates) {
        dbExecute(conn, 'UPDATE stations SET latitude = ?, longitude = ? WHERE station_id = ?', params = list(u$lat, u$lon, u$id))
      }
      updated <- dbGetQuery(conn, 'SELECT * FROM stations')
      write.csv(updated, paste0('stations_after_geocode_', Sys.Date(), '.csv'), row.names = FALSE)
      cat('Updated', length(updates), 'stations with coordinates.\n')
    } else {
      cat('No coordinates were found after enhanced search.\n')
    }
  }
}, error = function(e) {
  cat('Error:', conditionMessage(e), '\n')
}, finally = {
  dbDisconnect(conn)
})
