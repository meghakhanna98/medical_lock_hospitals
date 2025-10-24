# Medical Lock Hospitals Data Explorer
# Shiny App for data exploration and cleaning

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
library(tidyr)

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
      menuItem("Data Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("Data Tables", tabName = "tables", icon = icon("table")),
      menuItem("Data Cleaning", tabName = "cleaning", icon = icon("broom")),
      menuItem("Visualizations", tabName = "visualizations", icon = icon("chart-bar")),
      menuItem("Data Export", tabName = "export", icon = icon("download"))
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
      # Overview Tab
      tabItem(tabName = "overview",
        fluidRow(
          box(
            title = "Database Summary", status = "primary", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(3, 
                valueBoxOutput("total_documents", width = 12)
              ),
              column(3,
                valueBoxOutput("total_stations", width = 12)
              ),
              column(3,
                valueBoxOutput("total_women_records", width = 12)
              ),
              column(3,
                valueBoxOutput("total_troop_records", width = 12)
              )
            ),
            br(),
            fluidRow(
              column(6,
                box(
                  title = "Data Quality Summary", status = "info", solidHeader = TRUE,
                  width = 12,
                  DT::dataTableOutput("quality_summary")
                )
              ),
              column(6,
                box(
                  title = "Missing Data Overview", status = "warning", solidHeader = TRUE,
                  width = 12,
                  plotlyOutput("missing_data_plot")
                )
              )
            )
          )
        )
      ),
      
      # Data Tables Tab
      tabItem(tabName = "tables",
        fluidRow(
          box(
            title = "Select Table to View", status = "primary", solidHeader = TRUE,
            width = 12,
            selectInput("table_select", "Choose Table:",
              choices = c("documents", "stations", "station_reports", 
                         "women_admission", "troops", "hospital_operations"),
              selected = "documents"
            ),
            br(),
            DT::dataTableOutput("data_table")
          )
        )
      ),
      
      # Data Cleaning Tab
      tabItem(tabName = "cleaning",
        fluidRow(
          box(
            title = "Data Cleaning Tools", status = "success", solidHeader = TRUE,
            width = 12,
            tabsetPanel(
              tabPanel("Duplicate Detection",
                br(),
                selectInput("clean_table_select", "Select Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations")
                ),
                actionButton("find_duplicates", "Find Duplicates", class = "btn-warning"),
                br(), br(),
                DT::dataTableOutput("duplicates_table")
              ),
              
              tabPanel("Data Validation",
                br(),
                selectInput("validate_table_select", "Select Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations")
                ),
                actionButton("validate_data", "Validate Data", class = "btn-info"),
                br(), br(),
                verbatimTextOutput("validation_results")
              ),
              
              tabPanel("Filter & Search",
                br(),
                selectInput("filter_table_select", "Select Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations")
                ),
                uiOutput("filter_controls"),
                br(),
                DT::dataTableOutput("filtered_table")
              )
            )
          )
        )
      ),
      
      # Visualizations Tab
      tabItem(tabName = "visualizations",
        fluidRow(
          box(
            title = "Data Visualizations", status = "info", solidHeader = TRUE,
            width = 12,
            tabsetPanel(
              tabPanel("Temporal Analysis",
                br(),
                selectInput("time_plot_type", "Plot Type:",
                  choices = c("Women Data by Year", "Troop Data by Year", 
                             "Hospital Operations by Year", "Combined Timeline")
                ),
                plotlyOutput("temporal_plot")
              ),
              
              tabPanel("Geographic Analysis",
                br(),
                selectInput("geo_plot_type", "Geographic View:",
                  choices = c("Stations by Region", "Operations by Country", 
                             "Regional Distribution")
                ),
                plotlyOutput("geographic_plot")
              ),
              
              tabPanel("Statistical Analysis",
                br(),
                selectInput("stat_plot_type", "Statistical View:",
                  choices = c("Women vs Troop Strength", "Station Activity Levels",
                             "Document Coverage")
                ),
                plotlyOutput("statistical_plot")
              ),
              
              tabPanel("Medicalization",
                br(),
                tabsetPanel(
                  tabPanel("Temporal",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_temporal_women_added")),
                      column(6, plotlyOutput("med_temporal_avg_registered"))
                    ),
                    fluidRow(
                      column(6, plotlyOutput("med_temporal_ops_over_time")),
                      column(6, plotlyOutput("med_temporal_records_created"))
                    )
                  ),
                  tabPanel("Geography",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_geo_women_added_by_region")),
                      column(6, plotlyOutput("med_geo_avg_registered_by_region"))
                    )
                  ),
                  tabPanel("Disease",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_disease_pie")),
                      column(6, plotlyOutput("med_disease_bar"))
                    )
                  ),
                  tabPanel("Punitive",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_punitive_fines")),
                      column(6, plotlyOutput("med_punitive_imprisonment"))
                    ),
                    fluidRow(
                      column(6, plotlyOutput("med_punitive_non_attendance")),
                      column(6, plotlyOutput("med_punitive_totals"))
                    )
                  ),
                  tabPanel("Military-Medical",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_military_strength")),
                      column(6, plotlyOutput("med_military_vd_cases"))
                    ),
                    fluidRow(
                      column(6, plotlyOutput("med_military_types")),
                      column(6, plotlyOutput("med_military_correlation"))
                    )
                  ),
                  tabPanel("Acts",
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("med_acts_total")),
                      column(6, plotlyOutput("med_acts_timeline"))
                    ),
                    br(),
                    DT::dataTableOutput("med_acts_by_station")
                  ),
                  tabPanel("Summary",
                    br(),
                    htmlOutput("med_summary_html")
                  ),
                  tabPanel("Stations Map",
                    br(),
                    leafletOutput("stations_map", height = 600)
                  )
                )
              )
            )
          )
        )
      ),
      
      # Export Tab
      tabItem(tabName = "export",
        fluidRow(
          box(
            title = "Data Export", status = "success", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(6,
                selectInput("export_table", "Select Table to Export:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations")
                ),
                selectInput("export_format", "Export Format:",
                  choices = c("CSV", "Excel", "JSON")
                ),
                actionButton("export_data", "Export Data", class = "btn-success")
              ),
              column(6,
                h4("Custom Query Export"),
                textAreaInput("custom_query", "Enter SQL Query:", 
                  placeholder = "SELECT * FROM women_admission WHERE year > 1880",
                  rows = 4
                ),
                actionButton("export_query", "Export Query Results", class = "btn-primary")
              )
            ),
            br(),
            verbatimTextOutput("export_status")
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
  
  # Overview Tab - Value Boxes
  output$total_documents <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM documents")$count
    valueBox(count, "Documents", icon = icon("file-alt"), color = "blue")
  })
  
  output$total_stations <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM stations")$count
    valueBox(count, "Stations", icon = icon("map-marker-alt"), color = "green")
  })
  
  output$total_women_records <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM women_admission")$count
    valueBox(count, "Women Records", icon = icon("female"), color = "purple")
  })
  
  output$total_troop_records <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM troops")$count
    valueBox(count, "Troop Records", icon = icon("users"), color = "orange")
  })
  
  # Data Quality Summary
  output$quality_summary <- DT::renderDataTable({
    tables <- c("documents", "stations", "station_reports", "women_admission", "troops", "hospital_operations")
    total_records <- sapply(tables, function(t) {
      dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
    })
    complete_records <- sapply(tables, function(t) {
      if (t == "documents") {
        dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL AND source_name IS NOT NULL"))$count
      } else if (t == "stations") {
        dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE name IS NOT NULL"))$count
      } else {
        cols <- dbGetQuery(conn(), paste0("PRAGMA table_info(", t, ")"))$name
        if ("unique_id" %in% cols) {
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE unique_id IS NOT NULL"))$count
        } else if ("hid" %in% cols) {
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE hid IS NOT NULL"))$count
        } else {
          # Fallback: consider all records complete
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
        }
      }
    })
    quality_data <- data.frame(Table = tables, Total_Records = total_records, Complete_Records = complete_records)
    quality_data$Completeness <- round(quality_data$Complete_Records / quality_data$Total_Records * 100, 1)
    quality_data
  }, options = list(pageLength = 6, dom = 't'))
  
  # Missing Data Plot
  output$missing_data_plot <- renderPlotly({
    tables <- c("documents", "stations", "station_reports", "women_admission", "troops", "hospital_operations")
    missing_data <- lapply(tables, function(t) {
      total <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
      if (t == "documents") {
        complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL AND source_name IS NOT NULL"))$count
      } else if (t == "stations") {
        complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE name IS NOT NULL"))$count
      } else {
        cols <- dbGetQuery(conn(), paste0("PRAGMA table_info(", t, ")"))$name
        if ("unique_id" %in% cols) {
          complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE unique_id IS NOT NULL"))$count
        } else if ("hid" %in% cols) {
          complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE hid IS NOT NULL"))$count
        } else {
          complete <- 0
        }
      }
      data.frame(Table = t, Missing_Percentage = ifelse(total > 0, round((total - complete) / total * 100, 1), 0))
    }) %>% dplyr::bind_rows()

    p <- ggplot(missing_data, aes(x = Table, y = Missing_Percentage, fill = Table)) +
      geom_bar(stat = "identity") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(title = "Missing Data Percentage by Table", 
           x = "Table", y = "Missing Data (%)") +
      scale_fill_viridis_d()

    ggplotly(p)
  })
  
  # Data Tables Tab
  output$data_table <- DT::renderDataTable({
    query <- paste("SELECT * FROM", input$table_select)
    data <- dbGetQuery(conn(), query)
    DT::datatable(data, options = list(
      pageLength = 25,
      scrollX = TRUE,
      dom = 'Bfrtip',
      buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
    ), extensions = 'Buttons')
  })
  
  # Data Cleaning - Duplicate Detection
  observeEvent(input$find_duplicates, {
    table_name <- input$clean_table_select
    
    if (table_name == "documents") {
      query <- paste("SELECT doc_id, source_name, type, COUNT(*) as count FROM", table_name, 
                     "GROUP BY doc_id, source_name, type HAVING COUNT(*) > 1")
    } else if (table_name == "stations") {
      query <- paste("SELECT name, region, country, COUNT(*) as count FROM", table_name, 
                     "GROUP BY name, region, country HAVING COUNT(*) > 1")
    } else {
      query <- paste("SELECT * FROM", table_name, "WHERE rowid NOT IN (SELECT MIN(rowid) FROM", table_name, "GROUP BY", 
                     ifelse(table_name %in% c("women_admission", "troops"), "unique_id", "hid"), ")")
    }
    
    duplicates <- dbGetQuery(conn(), query)
    output$duplicates_table <- DT::renderDataTable({
      DT::datatable(duplicates, options = list(pageLength = 10))
    })
  })
  
  # Data Cleaning - Validation
  observeEvent(input$validate_data, {
    table_name <- input$validate_table_select
    
    validation_results <- paste("Validation Results for", table_name, ":\n\n")
    
    # Check for NULL values in key columns
    if (table_name == "documents") {
      null_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id IS NULL OR source_name IS NULL"))
      validation_results <- paste(validation_results, "Records with NULL doc_id or source_name:", null_check$count, "\n")
    } else if (table_name == "stations") {
      null_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE name IS NULL"))
      validation_results <- paste(validation_results, "Records with NULL name:", null_check$count, "\n")
    }
    
    # Check for empty strings
    empty_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id = '' OR source_name = ''"))
    validation_results <- paste(validation_results, "Records with empty strings:", empty_check$count, "\n")
    
    output$validation_results <- renderText(validation_results)
  })
  
  # Filter Controls
  output$filter_controls <- renderUI({
    table_name <- input$filter_table_select
    
    # Get column names for the selected table
    columns <- dbGetQuery(conn(), paste("PRAGMA table_info(", table_name, ")"))$name
    
    fluidRow(
      column(6,
        selectInput("filter_column", "Filter Column:", choices = columns)
      ),
      column(6,
        textInput("filter_value", "Filter Value:", placeholder = "Enter value to filter by")
      )
    )
  })
  
  # Filtered Table
  output$filtered_table <- DT::renderDataTable({
    table_name <- input$filter_table_select
    column <- input$filter_column
    value <- input$filter_value
    
    if (!is.null(column) && !is.null(value) && value != "") {
      query <- paste("SELECT * FROM", table_name, "WHERE", column, "LIKE '%", value, "%'")
    } else {
      query <- paste("SELECT * FROM", table_name)
    }
    
    data <- dbGetQuery(conn(), query)
    DT::datatable(data, options = list(pageLength = 25))
  })
  
  # Visualizations - Temporal Analysis
  output$temporal_plot <- renderPlotly({
    if (input$time_plot_type == "Women Data by Year") {
      data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM women_admission WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      p <- ggplot(data, aes(x = year, y = count)) +
        geom_line(color = "purple", size = 1) +
        geom_point(color = "purple", size = 2) +
        theme_minimal() +
        labs(title = "Women Data Records by Year", x = "Year", y = "Number of Records")
    } else if (input$time_plot_type == "Troop Data by Year") {
      data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM troops WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      p <- ggplot(data, aes(x = year, y = count)) +
        geom_line(color = "orange", size = 1) +
        geom_point(color = "orange", size = 2) +
        theme_minimal() +
        labs(title = "Troop Data Records by Year", x = "Year", y = "Number of Records")
    } else if (input$time_plot_type == "Hospital Operations by Year") {
      data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM hospital_operations WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      p <- ggplot(data, aes(x = year, y = count)) +
        geom_line(color = "blue", size = 1) +
        geom_point(color = "blue", size = 2) +
        theme_minimal() +
        labs(title = "Hospital Operations by Year", x = "Year", y = "Number of Operations")
    } else {
      # Combined timeline
      women_data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM women_admission WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      troop_data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM troops WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      
      women_data$type <- "Women Data"
      troop_data$type <- "Troop Data"
      
      combined_data <- rbind(women_data, troop_data)
      
      p <- ggplot(combined_data, aes(x = year, y = count, color = type)) +
        geom_line(size = 1) +
        geom_point(size = 2) +
        theme_minimal() +
        labs(title = "Combined Timeline: Women vs Troop Data", x = "Year", y = "Number of Records") +
        scale_color_manual(values = c("purple", "orange"))
    }
    
    ggplotly(p)
  })
  
  # Geographic Analysis
  output$geographic_plot <- renderPlotly({
    if (input$geo_plot_type == "Stations by Region") {
      data <- dbGetQuery(conn(), "SELECT region, COUNT(*) as count FROM stations WHERE region IS NOT NULL GROUP BY region ORDER BY count DESC")
      if (nrow(data) == 0) {
        return(ggplotly(ggplot() + theme_void() + ggtitle("No data for Stations by Region")))
      }
      p <- ggplot(data, aes(x = reorder(region, count), y = count, fill = region)) +
        geom_bar(stat = "identity") +
        coord_flip() +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(title = "Stations by Region", x = "Region", y = "Number of Stations")
    } else if (input$geo_plot_type == "Operations by Country") {
      data <- dbGetQuery(conn(), "SELECT country, COUNT(*) as count FROM hospital_operations WHERE country IS NOT NULL GROUP BY country ORDER BY count DESC")
      if (nrow(data) == 0) {
        return(ggplotly(ggplot() + theme_void() + ggtitle("No data for Operations by Country")))
      }
      p <- ggplot(data, aes(x = reorder(country, count), y = count, fill = country)) +
        geom_bar(stat = "identity") +
        coord_flip() +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(title = "Hospital Operations by Country", x = "Country", y = "Number of Operations")
    } else {
      # Regional Distribution
      data <- dbGetQuery(conn(), "SELECT region, COUNT(*) as count FROM stations WHERE region IS NOT NULL GROUP BY region ORDER BY count DESC")
      if (nrow(data) == 0) {
        return(ggplotly(ggplot() + theme_void() + ggtitle("No data for Regional Distribution")))
      }
      p <- ggplot(data, aes(x = "", y = count, fill = region)) +
        geom_bar(stat = "identity", width = 1) +
        coord_polar("y", start = 0) +
        theme_void() +
        labs(title = "Regional Distribution of Stations") +
        theme(plot.title = element_text(hjust = 0.5))
    }
    
    ggplotly(p)
  })
  
  # Statistical Analysis
  output$statistical_plot <- renderPlotly({
    if (input$stat_plot_type == "Women vs Troop Strength") {
      # This would require joining data and calculating averages
      data <- dbGetQuery(conn(), "
        SELECT w.station, w.year, w.women_added, t.avg_strength 
        FROM women_admission w 
        LEFT JOIN troops t ON w.station = t.station AND w.year = t.year 
        WHERE w.women_added IS NOT NULL AND t.avg_strength IS NOT NULL
        LIMIT 50
      ")
      
      if (nrow(data) > 0) {
        p <- ggplot(data, aes(x = women_added, y = avg_strength)) +
          geom_point(alpha = 0.6, color = "blue") +
          geom_smooth(method = "lm", se = TRUE) +
          theme_minimal() +
          labs(title = "Women Added vs Troop Average Strength", 
               x = "Women Added", y = "Average Troop Strength")
      } else {
        p <- ggplot() + 
          annotate("text", x = 0.5, y = 0.5, label = "No matching data found", size = 6) +
          theme_void()
      }
    } else if (input$stat_plot_type == "Station Activity Levels") {
      data <- dbGetQuery(conn(), "
        SELECT station, 
               COUNT(DISTINCT doc_id) as document_count,
               COUNT(*) as total_records
        FROM women_admission 
        WHERE station IS NOT NULL 
        GROUP BY station 
        ORDER BY total_records DESC 
        LIMIT 20
      ")
      
      p <- ggplot(data, aes(x = reorder(station, total_records), y = total_records)) +
        geom_bar(stat = "identity", fill = "steelblue") +
        coord_flip() +
        theme_minimal() +
        labs(title = "Station Activity Levels (Top 20)", x = "Station", y = "Total Records")
    } else {
      # Document Coverage
      data <- dbGetQuery(conn(), "
        SELECT d.doc_id, d.source_name, COUNT(sr.report_id) as report_count
        FROM documents d
        LEFT JOIN station_reports sr ON d.doc_id = sr.doc_id
        GROUP BY d.doc_id, d.source_name
        ORDER BY report_count DESC
      ")
      
      p <- ggplot(data, aes(x = reorder(doc_id, report_count), y = report_count)) +
        geom_bar(stat = "identity", fill = "darkgreen") +
        coord_flip() +
        theme_minimal() +
        labs(title = "Document Coverage by Station Reports", x = "Document ID", y = "Number of Station Reports")
    }
    
    ggplotly(p)
  })
  
  # Export functionality
  observeEvent(input$export_data, {
    table_name <- input$export_table
    format <- input$export_format
    
    data <- dbGetQuery(conn(), paste("SELECT * FROM", table_name))
    
    if (format == "CSV") {
      filename <- paste0(table_name, "_export.csv")
      write.csv(data, filename, row.names = FALSE)
      output$export_status <- renderText(paste("Data exported to", filename))
    } else if (format == "Excel") {
      filename <- paste0(table_name, "_export.xlsx")
      writexl::write_xlsx(data, filename)
      output$export_status <- renderText(paste("Data exported to", filename))
    } else {
      filename <- paste0(table_name, "_export.json")
      jsonlite::write_json(data, filename)
      output$export_status <- renderText(paste("Data exported to", filename))
    }
  })

  # =====================
  # Medicalization visuals (new)
  # =====================
  women_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM women_admission")
  })
  ops_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM hospital_operations")
  })
  troops_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM troops")
  })
  stations_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM stations")
  })

  # Temporal
  output$med_temporal_women_added <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>%
      dplyr::summarise(women_added = sum(women_added, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, women_added)) +
      geom_line(color = "#e74c3c", linewidth = 1) +
      geom_point(color = "#e74c3c", size = 2) +
      theme_minimal() + labs(title = "Women Added to Registration System", x = "Year", y = "Number of Women")
    ggplotly(p)
  })
  output$med_temporal_avg_registered <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>%
      dplyr::summarise(avg_registered = sum(avg_registered, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, avg_registered)) +
      geom_line(color = "#3498db", linewidth = 1) +
      geom_point(color = "#3498db", size = 2) +
      theme_minimal() + labs(title = "Total Registered Women Under Surveillance", x = "Year", y = "Number of Women")
    ggplotly(p)
  })
  output$med_temporal_ops_over_time <- renderPlotly({
    o <- ops_df()
    validate(need(nrow(o) > 0, "No hospital_operations data found"))
    yearly <- o %>% dplyr::group_by(year) %>% dplyr::summarise(hospital_count = dplyr::n(), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, hospital_count)) +
      geom_col(fill = "#2ecc71", alpha = 0.8) +
      theme_minimal() + labs(title = "Lock Hospital Operations", x = "Year", y = "Number of Hospital Operations")
    ggplotly(p)
  })
  output$med_temporal_records_created <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>% dplyr::summarise(records = dplyr::n(), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, records)) +
      geom_line(color = "#9b59b6", linewidth = 1) +
      geom_point(color = "#9b59b6", size = 2) +
      theme_minimal() + labs(title = "Bureaucratic Output: Data Records Created", x = "Year", y = "Number of Records")
    ggplotly(p)
  })

  # Geography
  output$med_geo_women_added_by_region <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    reg <- w %>% dplyr::group_by(region) %>% dplyr::summarise(women_added = sum(women_added, na.rm = TRUE), .groups = 'drop') %>% dplyr::filter(!is.na(region)) %>% dplyr::arrange(women_added)
    p <- ggplot(reg, aes(x = reorder(region, women_added), y = women_added)) +
      geom_col(fill = "#e67e22", alpha = 0.85) + coord_flip() + theme_minimal() +
      labs(title = "Women Added to System by Region", x = "Region", y = "Number of Women")
    ggplotly(p)
  })
  output$med_geo_avg_registered_by_region <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    reg <- w %>% dplyr::group_by(region) %>% dplyr::summarise(avg_registered = sum(avg_registered, na.rm = TRUE), .groups = 'drop') %>% dplyr::filter(!is.na(region)) %>% dplyr::arrange(avg_registered)
    p <- ggplot(reg, aes(x = reorder(region, avg_registered), y = avg_registered)) +
      geom_col(fill = "#1abc9c", alpha = 0.85) + coord_flip() + theme_minimal() +
      labs(title = "Total Registered Women by Region", x = "Region", y = "Number of Women")
    ggplotly(p)
  })

  # Disease
  output$med_disease_pie <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    totals <- data.frame(
      Disease = c("Primary Syphilis", "Secondary Syphilis", "Gonorrhoea", "Leucorrhoea"),
      Cases = c(sum(w$disease_primary_syphilis, na.rm = TRUE),
                sum(w$disease_secondary_syphilis, na.rm = TRUE),
                sum(w$disease_gonorrhoea, na.rm = TRUE),
                sum(w$disease_leucorrhoea, na.rm = TRUE))
    )
    plot_ly(totals, labels = ~Disease, values = ~Cases, type = 'pie',
            textinfo = 'label+percent', insidetextorientation = 'radial',
            marker = list(colors = c('#e74c3c','#c0392b','#e67e22','#f39c12')))
  })
  output$med_disease_bar <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    totals <- data.frame(
      Disease = c("Primary Syphilis", "Secondary Syphilis", "Gonorrhoea", "Leucorrhoea"),
      Cases = c(sum(w$disease_primary_syphilis, na.rm = TRUE),
                sum(w$disease_secondary_syphilis, na.rm = TRUE),
                sum(w$disease_gonorrhoea, na.rm = TRUE),
                sum(w$disease_leucorrhoea, na.rm = TRUE))
    )
    p <- ggplot(totals, aes(Disease, Cases, fill = Disease)) +
      geom_col(alpha = 0.85) + theme_minimal() + theme(legend.position = "none") +
      scale_fill_manual(values = c('#e74c3c','#c0392b','#e67e22','#f39c12')) +
      labs(title = "Total Cases by Disease Category", y = "Number of Cases") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    ggplotly(p)
  })

  # Punitive
  output$med_punitive_fines <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>% dplyr::summarise(fined_count = sum(fined_count, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, fined_count)) + geom_line(color = "#e74c3c") + geom_point(color = "#e74c3c") + theme_minimal() + labs(title = "Women Fined for Non-Compliance", x = "Year", y = "Number of Women Fined")
    ggplotly(p)
  })
  output$med_punitive_imprisonment <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>% dplyr::summarise(imprisonment_count = sum(imprisonment_count, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, imprisonment_count)) + geom_line(color = "#c0392b") + geom_point(color = "#c0392b") + theme_minimal() + labs(title = "Women Imprisoned for Non-Compliance", x = "Year", y = "Number of Women Imprisoned")
    ggplotly(p)
  })
  output$med_punitive_non_attendance <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    yearly <- w %>% dplyr::group_by(year) %>% dplyr::summarise(non_attendance_cases = sum(non_attendance_cases, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, non_attendance_cases)) + geom_line(color = "#f39c12") + geom_point(color = "#f39c12") + theme_minimal() + labs(title = "Non-Attendance Cases (Potential Resistance)", x = "Year", y = "Number of Non-Attendance Cases")
    ggplotly(p)
  })
  output$med_punitive_totals <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))
    totals <- data.frame(
      Category = c("Fines", "Imprisonments", "Non-Attendance (Resistance)"),
      Count = c(sum(w$fined_count, na.rm = TRUE), sum(w$imprisonment_count, na.rm = TRUE), sum(w$non_attendance_cases, na.rm = TRUE))
    )
    p <- ggplot(totals, aes(Category, Count, fill = Category)) + geom_col(alpha = 0.85) + theme_minimal() + theme(legend.position = "none") + labs(title = "Total Punitive Actions & Resistance", y = "Count")
    ggplotly(p)
  })

  # Military-Medical
  output$med_military_strength <- renderPlotly({
    t <- troops_df()
    validate(need(nrow(t) > 0, "No troops data found"))
    yearly <- t %>% dplyr::group_by(year) %>% dplyr::summarise(avg_strength = sum(avg_strength, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, avg_strength)) + geom_line(color = "#34495e") + geom_point(color = "#34495e") + theme_minimal() + labs(title = "Military Troop Strength", x = "Year", y = "Average Troop Strength")
    ggplotly(p)
  })
  output$med_military_vd_cases <- renderPlotly({
    t <- troops_df()
    validate(need(nrow(t) > 0, "No troops data found"))
    yearly <- t %>% dplyr::group_by(year) %>% dplyr::summarise(total_admissions = sum(total_admissions, na.rm = TRUE), .groups = 'drop') %>% dplyr::arrange(year)
    p <- ggplot(yearly, aes(year, total_admissions)) + geom_line(color = "#e74c3c") + geom_point(color = "#e74c3c") + theme_minimal() + labs(title = "Venereal Disease Cases in Military", x = "Year", y = "Total VD Admissions")
    ggplotly(p)
  })
  output$med_military_types <- renderPlotly({
    t <- troops_df()
    validate(need(nrow(t) > 0, "No troops data found"))
    totals <- data.frame(
      Type = c("Primary Syphilis", "Secondary Syphilis", "Gonorrhoea"),
      Cases = c(sum(t$primary_syphilis, na.rm = TRUE), sum(t$secondary_syphilis, na.rm = TRUE), sum(t$gonorrhoea, na.rm = TRUE))
    )
    p <- ggplot(totals, aes(Type, Cases, fill = Type)) + geom_col(alpha = 0.85) + theme_minimal() + theme(legend.position = "none") + labs(title = "Military VD Cases by Type", y = "Number of Cases")
    ggplotly(p)
  })
  output$med_military_correlation <- renderPlotly({
    df <- dbGetQuery(conn(), "
      SELECT 
        t.station,
        t.year,
        t.total_admissions as troop_disease,
        w.women_added as women_added
      FROM troops t
      LEFT JOIN women_admission w ON t.station = w.station AND t.year = w.year
      WHERE t.total_admissions IS NOT NULL AND w.women_added IS NOT NULL
    ")
    if (nrow(df) == 0) {
      return(ggplotly(ggplot() + theme_void() + ggtitle("No matching data found")))
    }
    p <- ggplot(df, aes(troop_disease, women_added)) + geom_point(alpha = 0.6, color = "#9b59b6") + theme_minimal() + labs(title = "Correlation: Military Disease & Women Surveillance", x = "Military VD Cases", y = "Women Added to System")
    ggplotly(p)
  })

  # Acts
  output$med_acts_total <- renderPlotly({
    acts <- dbGetQuery(conn(), "
      SELECT act, COUNT(*) as count 
      FROM hospital_operations 
      WHERE act IS NOT NULL AND act != 'None'
      GROUP BY act 
      ORDER BY count DESC
    ")
    validate(need(nrow(acts) > 0, "No acts data found"))
    p <- ggplot(acts, aes(x = reorder(act, count), y = count)) + geom_col(fill = "#2c3e50", alpha = 0.85) + coord_flip() + theme_minimal() + labs(title = "Implementation of CD Acts", x = "Act", y = "Number of Implementations")
    ggplotly(p)
  })
  output$med_acts_timeline <- renderPlotly({
    acts_temp <- dbGetQuery(conn(), "
      SELECT year, act, COUNT(*) as count 
      FROM hospital_operations 
      WHERE act IS NOT NULL AND act != 'None'
      GROUP BY year, act
    ")
    validate(need(nrow(acts_temp) > 0, "No acts temporal data found"))
    p <- ggplot(acts_temp, aes(x = year, y = count, fill = act)) + geom_area(position = 'stack', alpha = 0.7) + theme_minimal() + labs(title = "Acts Implementation Timeline", x = "Year", y = "Number of Stations")
    ggplotly(p)
  })
  output$med_acts_by_station <- DT::renderDataTable({
    df <- dbGetQuery(conn(), "
      SELECT station, act, COUNT(*) as count
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND station IS NOT NULL
      GROUP BY station, act
      ORDER BY count DESC
    ")
    DT::datatable(df, options = list(pageLength = 10, scrollX = TRUE))
  })

  # Summary
  output$med_summary_html <- renderUI({
    w <- women_df(); t <- troops_df(); s <- stations_df(); o <- ops_df()
    if (nrow(w) == 0) return(HTML("<em>No women_admission data found</em>"))
    # Format helper
    fmt <- function(x) formatC(x, format = "f", big.mark = ",", digits = 0)
    stations_n <- fmt(nrow(s))
    women_n <- fmt(nrow(w))
    ops_n <- fmt(nrow(o))
    troops_n <- fmt(nrow(t))
    women_added <- fmt(sum(w$women_added, na.rm = TRUE))
    avg_registered <- fmt(sum(w$avg_registered, na.rm = TRUE))
    discharges <- fmt(sum(w$discharges, na.rm = TRUE))
    deaths <- fmt(sum(w$deaths, na.rm = TRUE))
    p1 <- fmt(sum(w$disease_primary_syphilis, na.rm = TRUE))
    p2 <- fmt(sum(w$disease_secondary_syphilis, na.rm = TRUE))
    gon <- fmt(sum(w$disease_gonorrhoea, na.rm = TRUE))
    leu <- fmt(sum(w$disease_leucorrhoea, na.rm = TRUE))
    total_disease <- fmt(sum(w$disease_primary_syphilis, na.rm = TRUE) + sum(w$disease_secondary_syphilis, na.rm = TRUE) + sum(w$disease_gonorrhoea, na.rm = TRUE) + sum(w$disease_leucorrhoea, na.rm = TRUE))
    fined <- fmt(sum(w$fined_count, na.rm = TRUE))
    impr <- fmt(sum(w$imprisonment_count, na.rm = TRUE))
    nonatt <- fmt(sum(w$non_attendance_cases, na.rm = TRUE))
    strength <- fmt(sum(t$avg_strength, na.rm = TRUE))
    vd <- fmt(sum(t$total_admissions, na.rm = TRUE))
    summary_text <- paste0(
      "<pre style='font-family:Menlo,monospace; white-space:pre-wrap'>",
      "THE TRANSFORMATION OF WOMEN'S BODIES INTO ADMINISTRATIVE CATEGORIES\n",
      "Data from British India Lock Hospitals (1873-1890)\n\n",
      "SCALE OF SURVEILLANCE\n",
      "   • ", stations_n, " Lock Hospital Stations across British India\n",
      "   • ", women_n, " Women's Records Created\n",
      "   • ", ops_n, " Hospital Operations Documented\n",
      "   • ", troops_n, " Military Troop Records\n\n",
      "WOMEN PROCESSED THROUGH THE SYSTEM\n",
      "   • ", women_added, " Women Added to Registration\n",
      "   • ", avg_registered, " Total Registered Women\n",
      "   • ", discharges, " Discharges\n",
      "   • ", deaths, " Deaths in System\n\n",
      "DISEASE CATEGORIZATION\n",
      "   • ", p1, " Primary Syphilis Cases\n",
      "   • ", p2, " Secondary Syphilis Cases\n",
      "   • ", gon, " Gonorrhoea Cases\n",
      "   • ", leu, " Leucorrhoea Cases\n",
      "   • ", total_disease, " TOTAL Disease Cases Documented\n\n",
      "PUNITIVE MEASURES\n",
      "   • ", fined, " Women Fined\n",
      "   • ", impr, " Women Imprisoned\n",
      "   • ", nonatt, " Non-Attendance Cases (Resistance)\n\n",
      "MILITARY RATIONALE\n",
      "   • ", strength, " Total Military Strength\n",
      "   • ", vd, " VD Cases in Military\n",
      "   • Women's bodies regulated to protect military health\n\n",
      "LEGAL FRAMEWORK\n",
      "   • Contagious Diseases Acts (CD Acts) - primary mechanism\n",
      "   • Act XIV of 1868, Act XXII of 1864, Act III of 1880\n",
      "   • Compulsory registration, examination, and detention\n",
      "</pre>"
    )
    HTML(summary_text)
  })

  # Stations Map
  output$stations_map <- renderLeaflet({
    st <- stations_df()
    validate(need(nrow(st) > 0, "No stations data found"))
    # Try to detect lat/lon column names
    lat_col <- NA; lon_col <- NA
    if (all(c('lat','lon') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lon' }
    if (all(c('lat','lng') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lng' }
    if (all(c('latitude','longitude') %in% names(st))) { lat_col <- 'latitude'; lon_col <- 'longitude' }
    validate(need(!is.na(lat_col) && !is.na(lon_col), "Stations are missing latitude/longitude columns"))
    st2 <- st %>% dplyr::filter(!is.na(.data[[lat_col]]), !is.na(.data[[lon_col]])) %>%
      dplyr::mutate(lat = as.numeric(.data[[lat_col]]), lon = as.numeric(.data[[lon_col]])) %>%
      dplyr::filter(lat <= 90, lat >= -90, lon <= 180, lon >= -180)
    # Robust popup label
    if ("name" %in% names(st2)) {
      st2$label_name <- st2$name
    } else if ("station" %in% names(st2)) {
      st2$label_name <- st2$station
    } else {
      st2$label_name <- "Station"
    }
    validate(need(nrow(st2) > 0, "No valid geolocated stations to display"))
    leaflet(st2) %>% addTiles() %>%
      addCircleMarkers(~lon, ~lat, radius = 5, color = "#2c7fb8", fillOpacity = 0.7,
        popup = ~paste0("<b>", label_name, "</b><br>Region: ", region, "<br>Country: ", country))
  })
  
  observeEvent(input$export_query, {
    query <- input$custom_query
    
    if (query != "") {
      tryCatch({
        data <- dbGetQuery(conn(), query)
        filename <- paste0("custom_query_export_", Sys.Date(), ".csv")
        write.csv(data, filename, row.names = FALSE)
        output$export_status <- renderText(paste("Query results exported to", filename))
      }, error = function(e) {
        output$export_status <- renderText(paste("Error executing query:", e$message))
      })
    } else {
      output$export_status <- renderText("Please enter a SQL query")
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)
