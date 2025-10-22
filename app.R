library(shiny)
library(DBI)
library(RSQLite)
library(DT)
library(plotly)
library(dplyr)
library(ggplot2)
library(shinyWidgets)
library(shinydashboard)
library(leaflet)
library(httr)
library(jsonlite)

# Database connection function
connect_to_db <- function() {
  db_path <- "medical_lock_hospitals.db"
  if (!file.exists(db_path)) {
    stop("Database file not found. Please ensure medical_lock_hospitals.db is in the working directory.")
  }
  dbConnect(RSQLite::SQLite(), db_path)
}

# UI
ui <- dashboardPage(
  dashboardHeader(title = "Medical Lock Hospitals Data Explorer"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Hospital Operations", tabName = "operations", icon = icon("hospital")),
      menuItem("Data Overview", tabName = "data_overview", icon = icon("info-circle")),
      menuItem("Data Tables", tabName = "tables", icon = icon("table")),
      menuItem("Analysis", tabName = "analysis", icon = icon("chart-bar")),
      menuItem("Visualizations", tabName = "visualizations", icon = icon("chart-line"))
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f4f4f4;
        }
        .box {
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
      "))
    ),
    
    tabItems(
      # Hospital Operations Tab
      tabItem(tabName = "operations",
        fluidRow(
          box(
            title = "Hospital Operations Explorer", status = "primary", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(3,
                selectInput("year", "Year:", choices = c("All"), selected = "All")
              ),
              column(3,
                selectInput("region", "Region:", choices = c("All"), selected = "All")
              ),
              column(3,
                selectInput("country", "Country:", choices = c("All"), selected = "All")
              ),
              column(3,
                selectInput("act", "Act:", choices = c("All"), selected = "All")
              )
            ),
            br(),
            DT::dataTableOutput("ops_table"),
            br(),
            downloadButton("download_csv", "Download Filtered Data")
          )
        ),
        fluidRow(
          box(
            title = "Summary Statistics", status = "info", solidHeader = TRUE,
            width = 12,
            plotlyOutput("ops_summary")
          )
        )
      ),

        # Data Overview Tab (empty for now)
        tabItem(tabName = "data_overview",
          h2("Data Overview"),
          p("This page will provide a summary of the data sources and key metrics. Coming soon!")
        ),
      
      # Data Tables Tab
      tabItem(tabName = "tables",
        fluidRow(
          box(
            title = "Database Tables", status = "success", solidHeader = TRUE,
            width = 12,
            selectInput("table_select", "Select Table:",
              choices = c("hospital_operations", "hospital_notes", "documents", "stations", "station_reports", "troops", "women_admission"),
              selected = "hospital_operations"
            ),
            conditionalPanel(
              condition = "input.table_select == 'stations'",
              div(
                h4("Stations Data (Click cells to edit)"),
                helpText("Click cells in Region, Country, Latitude, or Longitude to edit."),
                DTOutput("stations_editable")
              )
            ),
            conditionalPanel(
              condition = "input.table_select != 'stations'",
              DT::dataTableOutput("data_table")
            )
          )
        )
      ),
      
      # Analysis Tab
      tabItem(tabName = "analysis",
        fluidRow(
          box(
            title = "Temporal Analysis", status = "info", solidHeader = TRUE,
            width = 6,
            plotlyOutput("temporal_plot")
          ),
          box(
            title = "Geographic Distribution", status = "primary", solidHeader = TRUE,
            width = 6,
            plotlyOutput("geographic_plot")
          )
        ),
        fluidRow(
          box(
            title = "Map Controls", status = "info", solidHeader = TRUE,
            width = 12,
            actionButton("geocode_missing", "Geocode missing stations", icon = icon("map-marker-alt")),
            helpText("Click to geocode stations missing latitude/longitude using Nominatim (runs from the app host).")
          )
        ),
        fluidRow(
          box(
            title = "Data Quality Overview", status = "success", solidHeader = TRUE,
            width = 12,
            DT::dataTableOutput("quality_summary")
          )
        )
      )
      ,
      # Visualizations Tab
      tabItem(tabName = "visualizations",
        fluidRow(
          box(
            title = "Acts by Station", status = "primary", solidHeader = TRUE,
            width = 6,
            selectInput("viz_act", "Act:", choices = c("All"), selected = "All"),
            selectInput("viz_region", "Region:", choices = c("All"), selected = "All"),
            plotlyOutput("acts_by_station")
          ),
          box(
            title = "Stations Map", status = "info", solidHeader = TRUE,
            width = 6,
            actionButton("geocode_missing_viz", "Geocode missing stations", icon = icon("map-marker-alt")),
            helpText("Markers show stations. Click a marker for acts and counts."),
            leafletOutput("stations_map", height = 550)
          )
        ),
        fluidRow(
          box(
            title = "Acts Table", status = "success", solidHeader = TRUE,
            width = 12,
            DT::dataTableOutput("acts_table")
          )
        )
      )
    )
  )
)

# Server
server <- function(input, output, session) {
  # Database connection
  conn <- reactive({
    connect_to_db()
  })
  
  # Close connection when app stops
  onStop(function() {
    if (exists("conn")) {
      dbDisconnect(conn())
    }
  })
  
  # Reactive value for hospital operations data
  ops_data <- reactive({
    data <- dbGetQuery(conn(), "SELECT * FROM hospital_operations")
    if ("year" %in% names(data)) data$year <- as.integer(data$year)
    return(data)
  })
  
  # Update filter choices
  observe({
    data <- ops_data()
    updateSelectInput(session, "year", 
      choices = c("All", sort(unique(na.omit(data$year)))),
      selected = "All"
    )
    updateSelectInput(session, "region", 
      choices = c("All", sort(unique(na.omit(data$region)))),
      selected = "All"
    )
    updateSelectInput(session, "country", 
      choices = c("All", sort(unique(na.omit(data$country)))),
      selected = "All"
    )
    updateSelectInput(session, "act", 
      choices = c("All", sort(unique(na.omit(data$act)))),
      selected = "All"
    )
  })
  
  # Filter data based on inputs
  filtered_data <- reactive({
    data <- ops_data()
    
    if (input$year != "All") {
      data <- data[data$year == as.integer(input$year), ]
    }
    if (input$region != "All") {
      data <- data[data$region == input$region, ]
    }
    if (input$country != "All") {
      data <- data[data$country == input$country, ]
    }
    if (input$act != "All") {
      data <- data[data$act == input$act, ]
    }
    
    return(data)
  })
  
  # Operations table output
  output$ops_table <- DT::renderDataTable({
    DT::datatable(
      filtered_data(),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      extensions = 'Buttons'
    )
  })
  
  # Download handler
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("hospital_operations_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
  
  # Operations summary plot
  output$ops_summary <- renderPlotly({
    data <- filtered_data()
    p <- plot_ly(data, x = ~year) %>%
      add_trace(type = "histogram", name = "Operations per Year") %>%
      layout(
        title = "Distribution of Operations by Year",
        xaxis = list(title = "Year"),
        yaxis = list(title = "Count")
      )
    p
  })
  
  # Data tables view
  output$data_table <- DT::renderDataTable({
    table_name <- input$table_select
    data <- dbGetQuery(conn(), paste("SELECT * FROM", table_name))
    # For stations table, rename 'name' to 'station_name' for display
    if (table_name == "stations" && "name" %in% names(data)) {
      names(data)[names(data) == "name"] <- "station_name"
    }
    DT::datatable(
      data,
      editable = TRUE,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      extensions = 'Buttons'
    )
  })

  # Handle table edits
  observeEvent(input$data_table_cell_edit, {
    info <- input$data_table_cell_edit
    i <- info$row
    j <- info$col + 1  # Column index is 0-based in the callback
    v <- info$value
    
    # Get current table name and data
    table_name <- input$table_select
    data <- dbGetQuery(conn(), paste("SELECT * FROM", table_name))
    col_names <- names(data)
    
    if (j >= 1 && j <= length(col_names)) {
      colname <- col_names[j]
      id_col <- names(data)[1]  # Assume first column is the ID column
      row_id <- data[[id_col]][i]
      
      # Execute update
      query <- sprintf("UPDATE %s SET %s = ? WHERE %s = ?", table_name, colname, id_col)
      dbExecute(conn(), query, params = list(v, row_id))
      
      # Show notification
      showNotification(
        sprintf("Updated %s to '%s' for row ID %s in table %s", colname, v, row_id, table_name),
        type = "message"
      )
    }
  })

  # Editable stations table for region/country/coordinates
  output$stations_editable <- DT::renderDT({
    data <- dbGetQuery(conn(), "SELECT station_id, name AS station_name, region, country, latitude, longitude FROM stations")
    datatable(
      data,
      editable = list(target = "cell", columns = c(3, 4, 5, 6)), # region (3), country (4), latitude (5), longitude (6)
      options = list(pageLength = 25, scrollX = TRUE)
    )
  })

  # Save edits to stations table
  observeEvent(input$stations_editable_cell_edit, {
    info <- input$stations_editable_cell_edit
    i <- info$row
    j <- info$col
    v <- info$value
    # Allow edits to region (3), country (4), latitude (5), longitude (6)
    if (j %in% c(3, 4, 5, 6)) {
      data <- dbGetQuery(conn(), "SELECT station_id, name AS station_name, region, country, latitude, longitude FROM stations")
      station_id <- data$station_id[i]
      colname <- switch(as.character(j), `3` = "region", `4` = "country", `5` = "latitude", `6` = "longitude")
      # Validate numeric for lat/lon
      if (colname %in% c("latitude", "longitude")) {
        num <- suppressWarnings(as.numeric(v))
        if (is.na(num)) {
          showNotification(sprintf("Invalid value '%s' for %s; please enter a number.", v, colname), type = "error")
          return()
        }
        # Optional bounds check
        if (colname == "latitude" && (num < -90 || num > 90)) {
          showNotification("Latitude must be between -90 and 90.", type = "error")
          return()
        }
        if (colname == "longitude" && (num < -180 || num > 180)) {
          showNotification("Longitude must be between -180 and 180.", type = "error")
          return()
        }
        v <- num
      }
      dbExecute(conn(), paste0("UPDATE stations SET ", colname, " = ? WHERE station_id = ?"), params = list(v, station_id))
      showNotification(paste("Updated", colname, "for station_id", station_id), type = "message")
    }
  })
  
  # Temporal analysis plot
  output$temporal_plot <- renderPlotly({
    data <- ops_data()
    yearly_counts <- data %>%
      group_by(year) %>%
      summarise(count = n()) %>%
      arrange(year)
    
    plot_ly(yearly_counts, x = ~year, y = ~count, type = "scatter", mode = "lines+markers") %>%
      layout(
        title = "Operations Over Time",
        xaxis = list(title = "Year"),
        yaxis = list(title = "Number of Operations")
      )
  })
  
  # Geographic distribution plot
  output$geographic_plot <- renderPlotly({
    data <- ops_data()
    region_counts <- data %>%
      group_by(region) %>%
      summarise(count = n()) %>%
      arrange(desc(count))
    
    plot_ly(region_counts, x = ~reorder(region, count), y = ~count, type = "bar") %>%
      layout(
        title = "Operations by Region",
        xaxis = list(title = "Region", tickangle = 45),
        yaxis = list(title = "Number of Operations")
      )
  })
  
  # Data quality summary
  output$quality_summary <- DT::renderDataTable({
    data <- ops_data()
    quality_df <- data.frame(
      Column = names(data),
      Total_Records = nrow(data),
      Missing_Values = sapply(data, function(x) sum(is.na(x))),
      Complete_Values = sapply(data, function(x) sum(!is.na(x))),
      Completeness_Pct = sapply(data, function(x) round(sum(!is.na(x))/length(x)*100, 2))
    )
    
    DT::datatable(
      quality_df,
      options = list(
        pageLength = 10,
        dom = 't'
      )
    )
  })

  # Populate Viz selectors
  observe({
    data <- ops_data()
    acts <- sort(unique(na.omit(data$act)))
    regions <- sort(unique(na.omit(data$region)))
    updateSelectInput(session, "viz_act", choices = c("All", acts), selected = "All")
    updateSelectInput(session, "viz_region", choices = c("All", regions), selected = "All")
  })

  # Acts by station plot
  output$acts_by_station <- renderPlotly({
    data <- ops_data()
    df <- data
    if (!is.null(input$viz_act) && input$viz_act != "All") df <- df[df$act == input$viz_act, ]
    if (!is.null(input$viz_region) && input$viz_region != "All") df <- df[df$region == input$viz_region, ]
    acts_station <- df %>% group_by(station) %>% summarise(count = n()) %>% arrange(desc(count)) %>% head(50)
    plot_ly(acts_station, x = ~reorder(station, count), y = ~count, type = 'bar') %>%
      layout(title = paste('Acts by Station', ifelse(input$viz_act == 'All', '', paste('-', input$viz_act))), xaxis = list(title = 'Station', tickangle = 45), yaxis = list(title = 'Count'))
  })

  # Acts table
  output$acts_table <- DT::renderDataTable({
    data <- ops_data()
    df <- data
    if (!is.null(input$viz_act) && input$viz_act != "All") df <- df[df$act == input$viz_act, ]
    if (!is.null(input$viz_region) && input$viz_region != "All") df <- df[df$region == input$viz_region, ]
    df %>% select(hid, station, region, country, year, act)
  }, options = list(pageLength = 25, scrollX = TRUE))

  # Stations map (clustered)
  output$stations_map <- renderLeaflet({
    ops <- ops_data()
    sts <- dbGetQuery(conn(), "SELECT station_id, name, region, country, latitude, longitude FROM stations")
    ops_counts <- ops %>% group_by(station) %>% summarise(count = n())
    map_df <- sts %>% left_join(ops_counts, by = c('name' = 'station'))
    m <- leaflet(map_df) %>% addProviderTiles(providers$CartoDB.Positron)
    coords <- map_df %>% filter(!is.na(latitude) & !is.na(longitude) & latitude != '' & longitude != '')
    if (nrow(coords) > 0) {
      # compute acts per station for popup
      acts_by_station <- ops %>% group_by(station, act) %>% summarise(n = n()) %>% arrange(station, desc(n))
      popup_info <- sapply(seq_len(nrow(coords)), function(i) {
        row <- coords[i, ]
        st_name <- row$name
        count <- ifelse(is.na(row$count), 0, row$count)
        acts_rows <- acts_by_station %>% filter(station == st_name)
        acts_html <- ''
        if (nrow(acts_rows) > 0) {
          items <- paste0('<li>', acts_rows$act, ' (', acts_rows$n, ')</li>', collapse = '')
          acts_html <- paste0('<ul>', items, '</ul>')
        } else {
          acts_html <- '<i>No acts recorded</i>'
        }
        paste0('<b>', st_name, '</b><br/>Region: ', row$region, '<br/>Operations: ', count, '<br/>Acts:', acts_html)
      })

      m <- m %>% addCircleMarkers(lng = coords$longitude, lat = coords$latitude,
                                  radius = ~ifelse(is.na(coords$count), 4, 4 + log1p(coords$count)),
                                  label = ~paste0(name, ' (', region, ')'),
                                  popup = popup_info,
                                  clusterOptions = markerClusterOptions())
    }
    m
  })

  # Geocode helper (Nominatim) - will run from the app host when button clicked
  geocode_one <- function(query) {
    url <- paste0('https://nominatim.openstreetmap.org/search?format=json&q=', URLencode(query))
    res <- tryCatch(httr::GET(url, httr::user_agent('medical_lock_geocoder/1.0 (contact@example.com)')), error = function(e) NULL)
    if (is.null(res) || res$status_code != 200) return(NULL)
    body <- httr::content(res, as = 'text', encoding = 'UTF-8')
    js <- jsonlite::fromJSON(body)
    if (length(js) == 0) return(NULL)
    return(list(lat = as.numeric(js[[1]]$lat), lon = as.numeric(js[[1]]$lon)))
  }

  geocode_missing_batch <- function() {
    showNotification('Geocoding started — this will call Nominatim for each missing station (rate-limited).', type = 'message')
    sts <- dbGetQuery(conn(), 'SELECT station_id, name, region, country, latitude, longitude FROM stations')
    missing <- sts %>% filter(is.na(latitude) | is.na(longitude) | latitude == '' | longitude == '')
    if (nrow(missing) == 0) { showNotification('No missing coordinates found.', type = 'message'); return(invisible()) }
    updates <- list()
    for (i in seq_len(nrow(missing))) {
      q <- paste(missing$name[i], missing$region[i], missing$country[i], sep = ', ')
      Sys.sleep(1) # polite pause
      geo <- geocode_one(q)
      if (!is.null(geo)) updates[[length(updates) + 1]] <- list(station_id = missing$station_id[i], lat = geo$lat, lon = geo$lon)
    }
    if (length(updates) > 0) {
      for (u in updates) {
        dbExecute(conn(), 'UPDATE stations SET latitude = ?, longitude = ? WHERE station_id = ?', params = list(u$lat, u$lon, u$station_id))
      }
      new_sts <- dbGetQuery(conn(), 'SELECT * FROM stations')
      write.csv(new_sts, 'stations_geocoded.csv', row.names = FALSE)
      showNotification(paste0('Geocoding complete. Updated ', length(updates), ' stations. Backup written to stations_geocoded.csv'), type = 'message')
    } else {
      showNotification('Geocoding completed but no coordinates were found.', type = 'warning')
    }
  }

  observeEvent(input$geocode_missing, { geocode_missing_batch() })
  observeEvent(input$geocode_missing_viz, { geocode_missing_batch() })
}

# Run the application
shinyApp(ui = ui, server = server)