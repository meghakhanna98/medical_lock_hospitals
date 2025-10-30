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

# Ensure images directory exists and serve as /images
if (!dir.exists("content/images")) {
  dir.create("content/images", recursive = TRUE, showWarnings = FALSE)
}
shiny::addResourcePath("images", "content/images")

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
      menuItem("Hospital Notes", tabName = "hospital_notes", icon = icon("clipboard")),
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
            title = "About This Dataset", status = "info", solidHeader = TRUE,
            width = 12,
            p(style = "font-size: 15px; line-height: 1.6;",
              "This dataset is built from nineteenth-century Lock Hospital Reports and Sanitary Commissioner's Reports produced under British rule in India. These records were part of a larger administrative effort to monitor women categorized as \"registered prostitutes\" under the Contagious Diseases Acts. Through these reports, the colonial state sought to control the spread of venereal disease among soldiers by transforming women's bodies into objects of record and inspection."
            ),
            p(style = "font-size: 15px; line-height: 1.6;",
              "The figures contained in these documents—women admitted, discharged, fined, or imprisoned; soldiers treated for disease; hospitals opened or closed—offer insight into how public health became a language of governance. What appeared as medical management was deeply tied to moral discipline and imperial control."
            ),
            p(style = "font-size: 15px; line-height: 1.6;",
              "Each entry in this dataset reflects the bureaucratic structure of the colonial state: the staffing of hospitals, the geography of cantonments, and the regular counting of \"registered\" and \"unregistered\" women. Taken together, these numbers allow us to see how the colonial government converted everyday life into data, turning acts of care into mechanisms of surveillance."
            ),
            p(style = "font-size: 15px; line-height: 1.6;",
              "Rather than treating these figures as neutral statistics, this project reads them as evidence of how medicine, morality, and governance became intertwined in the making of empire."
            )
          )
        ),
        br(),
        fluidRow(
          box(
            title = "From the Archives", status = "primary", solidHeader = TRUE,
            width = 12,
            p(style = "font-size: 14px;",
              "Selections from nineteenth-century reports and illustrations related to Lock Hospitals."),
            fileInput("archive_image_upload", "Upload images (JPG/PNG/WebP)", multiple = TRUE,
                      accept = c("image/png","image/jpeg","image/webp","image/gif")),
            helpText("You can also place files directly in content/images/."),
            uiOutput("overview_images")
          )
        ),
        br(),
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
              column(12,
                box(
                  title = "Data Quality Summary", status = "info", solidHeader = TRUE,
                  width = 12,
                  DT::dataTableOutput("quality_summary")
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
            title = "Medicalization Analysis", status = "info", solidHeader = TRUE,
            width = 12,
            tabsetPanel(
              tabPanel("Temporal",
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
                  ),
                  tabPanel("Temporal-Spatial Correlation",
                    br(),
                    fluidRow(
                      column(12,
                        h4("Surveillance Intensity vs. Military VD Pressure Over Time"),
                        p("This analysis reveals the relationship between troop venereal disease rates and women's registration — testing the military-medical nexus hypothesis."),
                        plotlyOutput("correlation_dual_axis", height = 500)
                      )
                    ),
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("correlation_scatter")),
                      column(6, plotlyOutput("correlation_heatmap"))
                    ),
                    br(),
                    fluidRow(
                      column(12,
                        h4("Normalized Metrics by Region"),
                        DT::dataTableOutput("correlation_metrics_table")
                      )
                    )
                  ),
                  tabPanel("Animated Timeline",
                    br(),
                    fluidRow(
                      column(12,
                        h4("Geographic Spread of Medicalization Over Time"),
                        p("Use the slider to animate the year-by-year expansion of surveillance. Circle size = registered women; color = punishment intensity."),
                        sliderInput("timeline_year", "Year:", 
                                    min = 1873, max = 1890, value = 1873, 
                                    step = 1, animate = animationOptions(interval = 1500, loop = TRUE)),
                        leafletOutput("animated_timeline_map", height = 600)
                      )
                    ),
                    br(),
                    fluidRow(
                      column(12,
                        h4("Year-over-Year Change"),
                        plotlyOutput("timeline_year_metrics")
                      )
                    )
                  ),
                  tabPanel("Disease Prevalence Map",
                    br(),
                    fluidRow(
                      column(12,
                        h4("Contagious Disease Distribution by Station"),
                        p("Each station shows the distribution of disease categories recorded in women and troops."),
                        selectInput("disease_map_metric", "Color stations by:",
                                    choices = c("Total Disease Cases" = "total_diseases",
                                               "Primary Syphilis Rate" = "primary_syphilis_rate",
                                               "Secondary Syphilis Rate" = "secondary_syphilis_rate",
                                               "Gonorrhoea Rate" = "gonorrhoea_rate",
                                               "Troop VD Pressure" = "troop_vd_rate"),
                                    selected = "total_diseases"),
                        leafletOutput("disease_prevalence_map", height = 600)
                      )
                    ),
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("disease_comparison_women")),
                      column(6, plotlyOutput("disease_comparison_troops"))
                    )
                  ),
                  tabPanel("Admissions by Region",
                    br(),
                    fluidRow(
                      column(12,
                        h4("Admissions over Time by Region (Women and Men)"),
                        p("Compare yearly admissions across regions. Women: sum of recorded disease cases; Men: total VD admissions in troops."),
                        selectizeInput("admissions_regions", "Regions:", choices = NULL, multiple = TRUE, options = list(plugins = list("remove_button")))
                      )
                    ),
                    br(),
                    fluidRow(
                      column(6, plotlyOutput("admissions_women_by_region")),
                      column(6, plotlyOutput("admissions_men_by_region"))
                    )
                  )
                )
              )
            )
          )
        )
      ),
      
      # Hospital Notes Tab
      tabItem(tabName = "hospital_notes",
        fluidRow(
          box(
            title = "Hospital Notes (Cleaned)", status = "primary", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(3,
                uiOutput("hn_station_select")
              ),
              column(3,
                uiOutput("hn_year_range")
              ),
              column(3,
                selectInput("hn_country", "Country:", choices = c("All"), selected = "All")
              ),
              column(3,
                textInput("hn_search", "Search Notes:", placeholder = "Find text in notes/remarks")
              )
            ),
            br(),
            fluidRow(
              column(12,
                DT::dataTableOutput("hospital_notes_table")
              )
            ),
            br(),
            fluidRow(
              column(6, downloadButton("download_hospital_notes", "Download CSV", class = "btn-success")),
              column(6, actionButton("hn_save_to_db", "Save Cleaned to Database", class = "btn-primary"))
            ),
            br(),
            verbatimTextOutput("hn_save_status")
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
    # Safely disconnect without triggering reactive context errors
    con_obj <- NULL
    try({ con_obj <- isolate(conn()) }, silent = TRUE)
    if (!is.null(con_obj)) try(DBI::dbDisconnect(con_obj), silent = TRUE)
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

  # Reactive bump to re-render images after upload
  archives_version <- reactiveVal(0)

  # Handle image uploads (copy into content/images)
  observeEvent(input$archive_image_upload, {
    files <- input$archive_image_upload
    req(files)
    dest_dir <- "content/images"
    if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    mapply(function(src, nm) {
      try(file.copy(src, file.path(dest_dir, nm), overwrite = TRUE), silent = TRUE)
    }, files$datapath, files$name)
    # Trigger refresh
    archives_version(archives_version() + 1)
  }, ignoreInit = TRUE)

  # Overview Tab - Images (archives)
  output$overview_images <- renderUI({
    v <- archives_version()  # dependency to refresh after uploads
    base_dir <- "content/images"
    # Preferred filenames (drop-in if you place the images with these names)
    preferred <- file.path(base_dir, c(
      "nwp_1877_cover.jpg",
      "british_burma_1875.jpg",
      "lock_hospital_hyde_park.jpg"
    ))
    files <- preferred[file.exists(preferred)]
    if (length(files) == 0 && dir.exists(base_dir)) {
      files <- list.files(base_dir, pattern = "\\.(png|jpg|jpeg|webp|gif)$", ignore.case = TRUE, full.names = TRUE)
    }
    files <- head(files, 3)
    if (length(files) == 0) {
      return(tags$div(style = "color:#666;", "Add images to content/images/ to display them here."))
    }
    srcs <- sub("^content/images/?", "images/", files)
    captions <- c(
      "Lock Hospitals Report, North-Western Provinces and Oudh (1877)",
      "Annual Report on Lock-Hospitals of British Burma (1875)",
      "Lock Hospital, Hyde Park Corner (illustration)"
    )
    tags$div(
      style = "display:flex; flex-wrap:wrap; gap:16px;",
      lapply(seq_along(srcs), function(i) {
        tags$div(style = "flex:1 1 300px; max-width: 100%;", 
          tags$img(src = srcs[i], style = "width:100%; height:auto; max-height:360px; object-fit:contain; border:1px solid #ddd; border-radius:6px; box-shadow:0 1px 3px rgba(0,0,0,0.15);"),
          tags$p(style = "margin-top:6px; font-size: 12px; color:#555;", captions[min(i, length(captions))])
        )
      })
    )
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
  
  # (Removed) Missing Data Plot - intentionally removed as per request
  
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
    dbGetQuery(conn(), "SELECT rowid AS __rowid__, * FROM hospital_operations")
  })
  notes_df <- reactive({
    dbGetQuery(conn(), "SELECT hid, ops_inspection_regularity, ops_unlicensed_control_notes, ops_committee_activity_notes, remarks FROM hospital_notes")
  })
  troops_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM troops")
  })
  stations_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM stations")
  })

  # ---------------------
  # Admissions by Region - controls
  # ---------------------
  observe({
    # Populate region choices from both datasets
    w <- women_df(); t <- troops_df()
    regions <- sort(unique(na.omit(c(w$region, t$region))))
    if (length(regions) > 0) {
      updateSelectizeInput(session, "admissions_regions", choices = regions, selected = regions, server = TRUE)
    }
  })

  # ---------------------
  # Hospital Notes helpers
  # ---------------------
  # Utility to trim and normalize whitespace
  .trim_ws <- function(x) {
    if (is.null(x)) return(x)
    x <- gsub("\n|\r", " ", x)
    x <- gsub("[\t ]+", " ", x)
    x <- trimws(x)
    x[x == ""] <- NA_character_
    x
  }
  # Remove non-ASCII and special characters except a safe punctuation set
  .strip_specials <- function(x) {
    if (is.null(x)) return(x)
    x0 <- as.character(x)
    # transliterate to ASCII and drop unconvertible
    x0 <- iconv(x0, to = "ASCII//TRANSLIT", sub = "")
  # keep letters, numbers, whitespace, and some common punctuation
  x0 <- gsub("[^A-Za-z0-9 \t\n\r.,;:!()'\"/?-]", "", x0)
    # collapse whitespace and trim
    x0 <- gsub("[\t ]+", " ", x0)
    x0 <- trimws(x0)
    x0[x0 == ""] <- NA_character_
    x0
  }
  # Extract integer from mixed text (e.g., "3 MO" -> 3)
  .parse_int <- function(x) {
    if (is.null(x)) return(NA_integer_)
    if (is.numeric(x)) return(as.integer(round(x)))
    digits <- suppressWarnings(as.integer(gsub("[^0-9]", "", as.character(x))))
    ifelse(is.na(digits) | is.nan(digits), NA_integer_, digits)
  }
  # Normalize inspection regularity to categories
  .normalize_regularity <- function(x) {
    # sanitize first to strip odd characters, then normalize
    x0 <- tolower(.strip_specials(.trim_ws(as.character(x))))
    dplyr::case_when(
      is.na(x0) ~ NA_character_,
      grepl("regular|weekly|monthly|quarterly|monthly|periodic", x0) & !grepl("irregular|infrequent|rare|sporadic", x0) ~ "Regular",
      grepl("irregular|infrequent|rare|sporadic|occasional", x0) ~ "Irregular",
      TRUE ~ "Other"
    )
  }

  # Reactive cleaned Hospital Notes dataset
  hospital_notes_df <- reactive({
    # Load ops table
    ops <- ops_df()
    if (nrow(ops) == 0) return(ops)
    cols <- dbGetQuery(conn(), "PRAGMA table_info(hospital_operations)")$name
    want <- c(
      "station","region","country","year",
      "staff_medical_officers","staff_hospital_assistants","staff_matron",
      "staff_coolies","staff_peons","staff_watermen",
      "ops_inspection_regularity","ops_unlicensed_control_notes",
      "ops_committee_activity_notes","remarks"
    )
    # Determine key column to enable DB updates later
    key_col <- if ("unique_id" %in% names(ops)) "unique_id" else if ("hid" %in% names(ops)) "hid" else "__rowid__"
    # Join in notes by HID to populate note fields
    nts <- notes_df()
    if (nrow(nts) > 0 && "hid" %in% names(ops)) {
      ops <- dplyr::left_join(ops, nts, by = "hid", suffix = c("", "_notes"))
      for (nm in c("ops_inspection_regularity","ops_unlicensed_control_notes","ops_committee_activity_notes","remarks")) {
        src <- paste0(nm, "_notes")
        if (src %in% names(ops)) {
          if (!(nm %in% names(ops))) ops[[nm]] <- NA
          ops[[nm]] <- dplyr::coalesce(ops[[src]], ops[[nm]])
        }
      }
    }
    # Ensure all desired columns exist (create NA if missing)
    for (nm in setdiff(want, names(ops))) ops[[nm]] <- NA
    keep_cols <- unique(c(key_col, want))
    ops <- ops[, intersect(c(keep_cols, names(ops)), keep_cols), drop = FALSE]

    ops %>%
      dplyr::mutate(
        staff_medical_officers = .parse_int(staff_medical_officers),
        staff_hospital_assistants = .parse_int(staff_hospital_assistants),
        staff_matron = .parse_int(staff_matron),
        staff_coolies = .parse_int(staff_coolies),
        staff_peons = .parse_int(staff_peons),
        staff_watermen = .parse_int(staff_watermen),
        ops_inspection_regularity = .normalize_regularity(ops_inspection_regularity),
        ops_unlicensed_control_notes = .strip_specials(ops_unlicensed_control_notes),
        ops_committee_activity_notes = .strip_specials(ops_committee_activity_notes),
        remarks = .strip_specials(remarks),
        staff_total = rowSums(cbind(
          as.integer(coalesce(staff_medical_officers, 0)),
          as.integer(coalesce(staff_hospital_assistants, 0)),
          as.integer(coalesce(staff_matron, 0)),
          as.integer(coalesce(staff_coolies, 0)),
          as.integer(coalesce(staff_peons, 0)),
          as.integer(coalesce(staff_watermen, 0))
        ), na.rm = TRUE),
        .key = .data[[key_col]],
        .key_col = key_col
      )
  })

  # ---------------------
  # Temporal-Spatial Correlation Metrics
  # ---------------------
  correlation_data <- reactive({
    w <- women_df()
    t <- troops_df()
    
    if (nrow(w) == 0 || nrow(t) == 0) return(data.frame())
    
    # Aggregate women data by year, region, station
    women_agg <- w %>%
      dplyr::group_by(year, region, station, country) %>%
      dplyr::summarise(
        total_women_added = sum(women_added, na.rm = TRUE),
        total_avg_registered = sum(avg_registered, na.rm = TRUE),
        total_fined = sum(fined_count, na.rm = TRUE),
        total_imprisoned = sum(imprisonment_count, na.rm = TRUE),
        total_disease_women = sum(disease_primary_syphilis + disease_secondary_syphilis + 
                                  disease_gonorrhoea + disease_leucorrhoea, na.rm = TRUE),
        primary_syphilis_women = sum(disease_primary_syphilis, na.rm = TRUE),
        secondary_syphilis_women = sum(disease_secondary_syphilis, na.rm = TRUE),
        gonorrhoea_women = sum(disease_gonorrhoea, na.rm = TRUE),
        leucorrhoea_women = sum(disease_leucorrhoea, na.rm = TRUE),
        .groups = 'drop'
      )
    
    # Aggregate troops data
    troops_agg <- t %>%
      dplyr::group_by(year, region, station, country) %>%
      dplyr::summarise(
        total_troop_strength = sum(avg_strength, na.rm = TRUE),
        total_vd_admissions = sum(total_admissions, na.rm = TRUE),
        primary_syphilis_troops = sum(primary_syphilis, na.rm = TRUE),
        secondary_syphilis_troops = sum(secondary_syphilis, na.rm = TRUE),
        gonorrhoea_troops = sum(gonorrhoea, na.rm = TRUE),
        .groups = 'drop'
      )
    
    # Merge women and troops
    merged <- dplyr::full_join(women_agg, troops_agg, by = c("year", "region", "station", "country"))
    
    # Calculate normalized metrics
    merged %>%
      dplyr::mutate(
        # Surveillance intensity (women per 1000 troops)
        surveillance_index = ifelse(total_troop_strength > 0, 
                                    (total_women_added + total_avg_registered) / total_troop_strength * 1000, 
                                    NA_real_),
        # Punishment rate (per 100 registered women)
        punishment_rate = ifelse(total_avg_registered > 0,
                                (total_fined + total_imprisoned * 2) / total_avg_registered * 100,
                                NA_real_),
        # Disease tracking rate (women)
        disease_tracking_rate = ifelse(total_avg_registered > 0,
                                       total_disease_women / total_avg_registered * 100,
                                       NA_real_),
        # Troop VD pressure (per 1000 troops)
        troop_vd_pressure = ifelse(total_troop_strength > 0,
                                   total_vd_admissions / total_troop_strength * 1000,
                                   NA_real_),
        # Disease rates
        primary_syphilis_rate = ifelse(total_avg_registered > 0,
                                       primary_syphilis_women / total_avg_registered * 100,
                                       NA_real_),
        secondary_syphilis_rate = ifelse(total_avg_registered > 0,
                                         secondary_syphilis_women / total_avg_registered * 100,
                                         NA_real_),
        gonorrhoea_rate = ifelse(total_avg_registered > 0,
                                gonorrhoea_women / total_avg_registered * 100,
                                NA_real_),
        troop_vd_rate = ifelse(total_troop_strength > 0,
                              (primary_syphilis_troops + secondary_syphilis_troops + gonorrhoea_troops) / total_troop_strength * 100,
                              NA_real_),
        total_diseases = total_disease_women
      ) %>%
      dplyr::filter(!is.na(year))
  })

  # Dynamic filter controls for Hospital Notes
  output$hn_station_select <- renderUI({
    df <- hospital_notes_df()
    stations <- sort(unique(na.omit(df$station)))
    selectInput("hn_station", "Station:", choices = c("All", stations), selected = "All")
  })
  output$hn_year_range <- renderUI({
    df <- hospital_notes_df()
    yr <- sort(unique(na.omit(as.integer(df$year))))
    if (length(yr) == 0) yr <- c(NA_integer_, NA_integer_)
    sliderInput("hn_year", "Year Range:", min = min(yr, na.rm = TRUE), max = max(yr, na.rm = TRUE), value = c(min(yr, na.rm = TRUE), max(yr, na.rm = TRUE)), sep = "")
  })

  # Update Country choices based on data
  observe({
    df <- hospital_notes_df()
    countries <- sort(unique(na.omit(df$country)))
    updateSelectInput(session, "hn_country", choices = c("All", countries), selected = "All")
  })

  # Filtered dataset for display/export
  hospital_notes_filtered <- reactive({
    df <- hospital_notes_df()
    if (nrow(df) == 0) return(df)
    # Apply filters
    if (!is.null(input$hn_station) && input$hn_station != "All") df <- df %>% dplyr::filter(.data$station == input$hn_station)
    if (!is.null(input$hn_country) && input$hn_country != "All") df <- df %>% dplyr::filter(.data$country == input$hn_country)
    if (!is.null(input$hn_year) && length(input$hn_year) == 2 && all(!is.na(input$hn_year))) {
      df <- df %>% dplyr::filter(dplyr::between(as.integer(.data$year), input$hn_year[1], input$hn_year[2]))
    }
    if (!is.null(input$hn_search) && nzchar(input$hn_search)) {
      kw <- tolower(input$hn_search)
      keep <- grepl(kw, tolower(paste(df$ops_unlicensed_control_notes, df$ops_committee_activity_notes, df$remarks)), fixed = TRUE)
      df <- df[keep, , drop = FALSE]
    }
    df
  })

  # Render table
  output$hospital_notes_table <- DT::renderDataTable({
    df <- hospital_notes_filtered()
    validate(need(nrow(df) > 0, "No hospital notes data available for current filters"))
    # Column order for display
    display_cols <- c(
      "station","region","country","year",
      "staff_medical_officers","staff_hospital_assistants","staff_matron",
      "staff_coolies","staff_peons","staff_watermen","staff_total",
      "ops_inspection_regularity","ops_unlicensed_control_notes","ops_committee_activity_notes","remarks"
    )
    missing <- setdiff(display_cols, names(df))
    for (m in missing) df[[m]] <- NA
    df <- df[, display_cols]
    DT::datatable(df, options = list(pageLength = 25, scrollX = TRUE, dom = 'Bfrtip', buttons = c('copy','csv','excel','print')), extensions = 'Buttons')
  })

  # Download cleaned notes
  output$download_hospital_notes <- downloadHandler(
    filename = function() paste0("hospital_notes_cleaned_", Sys.Date(), ".csv"),
    content = function(file) {
      df <- hospital_notes_filtered()
      write.csv(df, file, row.names = FALSE)
    }
  )

  # Persist cleaned notes back to the database (new)
  observeEvent(input$hn_save_to_db, {
    df <- hospital_notes_df()
    if (nrow(df) == 0) {
      output$hn_save_status <- renderText("No hospital operations data to save.")
      return()
    }
    # Identify key column name used for updates
    key_name <- unique(df$.key_col)[1]
    if (is.null(key_name) || is.na(key_name)) key_name <- "__rowid__"
    where_col <- if (identical(key_name, "__rowid__")) "rowid" else key_name

    # Ensure destination columns exist
    con <- conn()
    add_col <- function(sql) { tryCatch({ DBI::dbExecute(con, sql) }, error = function(e) {}) }
    add_col("ALTER TABLE hospital_operations ADD COLUMN ops_unlicensed_control_notes_clean TEXT")
    add_col("ALTER TABLE hospital_operations ADD COLUMN ops_committee_activity_notes_clean TEXT")
    add_col("ALTER TABLE hospital_operations ADD COLUMN remarks_clean TEXT")
    add_col("ALTER TABLE hospital_operations ADD COLUMN ops_inspection_regularity_norm TEXT")

    # Prepare update statement
    sql <- paste0(
      "UPDATE hospital_operations SET ",
      "ops_unlicensed_control_notes_clean = ?, ",
      "ops_committee_activity_notes_clean = ?, ",
      "remarks_clean = ?, ",
      "ops_inspection_regularity_norm = ? ",
      "WHERE ", where_col, " = ?"
    )

    # Execute updates in a transaction
    updated <- 0L
    DBI::dbBegin(con)
    err <- NULL
    for (i in seq_len(nrow(df))) {
      key_val <- df$.key[i]
      if (is.na(key_val)) next
      params <- list(
        df$ops_unlicensed_control_notes[i],
        df$ops_committee_activity_notes[i],
        df$remarks[i],
        df$ops_inspection_regularity[i],
        key_val
      )
      tryCatch({
        DBI::dbExecute(con, sql, params = params)
        updated <- updated + 1L
      }, error = function(e) {
        err <<- e$message
      })
      if (!is.null(err)) break
    }
    if (is.null(err)) {
      tryCatch(DBI::dbCommit(con), error = function(e) { err <<- e$message; DBI::dbRollback(con) })
    } else {
      DBI::dbRollback(con)
    }
    if (is.null(err)) {
      output$hn_save_status <- renderText(paste0("Saved cleaned fields to database for ", updated, " rows using key column '", where_col, "'."))
    } else {
      output$hn_save_status <- renderText(paste0("Error during save: ", err))
    }
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
  
  # ---------------------
  # Temporal-Spatial Correlation Outputs
  # ---------------------
  output$correlation_dual_axis <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    # Aggregate by year for dual-axis time series
    yearly <- corr %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(
        avg_surveillance_index = mean(surveillance_index, na.rm = TRUE),
        avg_troop_vd_pressure = mean(troop_vd_pressure, na.rm = TRUE),
        .groups = 'drop'
      ) %>%
      dplyr::filter(!is.na(avg_surveillance_index) | !is.na(avg_troop_vd_pressure))
    
    validate(need(nrow(yearly) > 0, "No yearly aggregate data available"))
    
    # Create dual-axis plot
    p <- plot_ly(yearly, x = ~year) %>%
      add_trace(y = ~avg_surveillance_index, name = 'Surveillance Index (Women per 1000 Troops)',
                type = 'scatter', mode = 'lines+markers', line = list(color = '#e74c3c', width = 2),
                marker = list(size = 8, color = '#e74c3c'), yaxis = 'y') %>%
      add_trace(y = ~avg_troop_vd_pressure, name = 'Troop VD Pressure (per 1000 Troops)',
                type = 'scatter', mode = 'lines+markers', line = list(color = '#3498db', width = 2),
                marker = list(size = 8, color = '#3498db'), yaxis = 'y2') %>%
      layout(
        title = list(text = 'Surveillance Intensity vs. Military VD Pressure (Dual-Axis)', font = list(size = 16)),
        xaxis = list(title = 'Year'),
        yaxis = list(title = 'Surveillance Index', titlefont = list(color = '#e74c3c'), tickfont = list(color = '#e74c3c')),
        yaxis2 = list(title = 'Troop VD Pressure', overlaying = 'y', side = 'right',
                      titlefont = list(color = '#3498db'), tickfont = list(color = '#3498db')),
        hovermode = 'x unified',
        shapes = list(
          # Mark Act XIV period (1868)
          list(type = 'line', x0 = 1868, x1 = 1868, y0 = 0, y1 = 1, yref = 'paper',
               line = list(color = 'orange', width = 2, dash = 'dash')),
          # Mark Act III period (1880)
          list(type = 'line', x0 = 1880, x1 = 1880, y0 = 0, y1 = 1, yref = 'paper',
               line = list(color = 'purple', width = 2, dash = 'dash'))
        ),
        annotations = list(
          list(x = 1868, y = 1, xref = 'x', yref = 'paper', text = 'Act XIV (1868)',
               showarrow = FALSE, xanchor = 'left', yanchor = 'bottom', font = list(color = 'orange', size = 10)),
          list(x = 1880, y = 1, xref = 'x', yref = 'paper', text = 'Act III (1880)',
               showarrow = FALSE, xanchor = 'left', yanchor = 'bottom', font = list(color = 'purple', size = 10))
        )
      )
    p
  })
  
  output$correlation_scatter <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    corr_clean <- corr %>% dplyr::filter(!is.na(surveillance_index), !is.na(troop_vd_pressure))
    validate(need(nrow(corr_clean) > 0, "No data points with both metrics"))
    
    p <- plot_ly(corr_clean, x = ~troop_vd_pressure, y = ~surveillance_index, 
                 text = ~paste0(station, " (", year, ")"), color = ~year, size = ~punishment_rate,
                 type = 'scatter', mode = 'markers', colors = 'Viridis',
                 marker = list(sizemode = 'diameter', sizeref = 0.5, line = list(width = 0.5, color = 'white'))) %>%
      layout(title = 'Military VD Pressure vs. Surveillance Intensity',
             xaxis = list(title = 'Troop VD Pressure (per 1000)'),
             yaxis = list(title = 'Surveillance Index (Women per 1000 Troops)'),
             hovermode = 'closest')
    p
  })
  
  output$correlation_heatmap <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    # Station x Year heatmap
    hm_data <- corr %>%
      dplyr::filter(!is.na(surveillance_index)) %>%
      dplyr::select(station, year, surveillance_index) %>%
      tidyr::pivot_wider(names_from = year, values_from = surveillance_index, values_fill = NA)
    
    validate(need(nrow(hm_data) > 1, "Insufficient data for heatmap"))
    
    stations <- hm_data$station
    hm_matrix <- as.matrix(hm_data[, -1])
    rownames(hm_matrix) <- stations
    
    plot_ly(z = hm_matrix, x = colnames(hm_matrix), y = rownames(hm_matrix),
            type = 'heatmap', colorscale = 'YlOrRd', showscale = TRUE) %>%
      layout(title = 'Surveillance Intensity Heatmap (Station × Year)',
             xaxis = list(title = 'Year'),
             yaxis = list(title = 'Station', tickfont = list(size = 8)))
  })
  
  output$correlation_metrics_table <- DT::renderDataTable({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    summary_table <- corr %>%
      dplyr::group_by(region) %>%
      dplyr::summarise(
        Stations = dplyr::n_distinct(station),
        `Avg Surveillance Index` = round(mean(surveillance_index, na.rm = TRUE), 2),
        `Avg Punishment Rate` = round(mean(punishment_rate, na.rm = TRUE), 2),
        `Avg Troop VD Pressure` = round(mean(troop_vd_pressure, na.rm = TRUE), 2),
        `Total Women Registered` = sum(total_avg_registered, na.rm = TRUE),
        `Total Troops` = sum(total_troop_strength, na.rm = TRUE),
        .groups = 'drop'
      ) %>%
      dplyr::arrange(desc(`Avg Surveillance Index`))
    
    DT::datatable(summary_table, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # ---------------------
  # Admissions by Region - Plots
  # ---------------------
  output$admissions_women_by_region <- renderPlotly({
    w <- women_df()
    validate(need(nrow(w) > 0, "No women data available"))

    # Compute women's admissions as sum of disease cases recorded
    w2 <- w %>%
      dplyr::mutate(
        year = as.integer(year),
        women_admissions = rowSums(cbind(
          suppressWarnings(as.numeric(disease_primary_syphilis)),
          suppressWarnings(as.numeric(disease_secondary_syphilis)),
          suppressWarnings(as.numeric(disease_gonorrhoea)),
          suppressWarnings(as.numeric(disease_leucorrhoea))
        ), na.rm = TRUE)
      ) %>%
      dplyr::filter(!is.na(year), !is.na(region)) %>%
      dplyr::group_by(year, region) %>%
      dplyr::summarise(total_women_adm = sum(women_admissions, na.rm = TRUE), .groups = 'drop')

    # Filter by selected regions if provided
    regs <- input$admissions_regions
    if (!is.null(regs) && length(regs) > 0) w2 <- dplyr::filter(w2, region %in% regs)

    validate(need(nrow(w2) > 0, "No data for selected regions"))

    plot_ly(w2, x = ~year, y = ~total_women_adm, color = ~region, type = 'scatter', mode = 'lines+markers') %>%
      layout(
        title = 'Women Admissions by Region (per year)',
        xaxis = list(title = 'Year'),
        yaxis = list(title = 'Total Women Admissions'),
        legend = list(orientation = 'h')
      )
  })

  output$admissions_men_by_region <- renderPlotly({
    t <- troops_df()
    validate(need(nrow(t) > 0, "No troops data available"))

    t2 <- t %>%
      dplyr::mutate(year = as.integer(year)) %>%
      dplyr::filter(!is.na(year), !is.na(region)) %>%
      dplyr::group_by(year, region) %>%
      dplyr::summarise(total_men_adm = sum(suppressWarnings(as.numeric(total_admissions)), na.rm = TRUE), .groups = 'drop')

    regs <- input$admissions_regions
    if (!is.null(regs) && length(regs) > 0) t2 <- dplyr::filter(t2, region %in% regs)

    validate(need(nrow(t2) > 0, "No data for selected regions"))

    plot_ly(t2, x = ~year, y = ~total_men_adm, color = ~region, type = 'scatter', mode = 'lines+markers') %>%
      layout(
        title = 'Men (Troops) Admissions by Region (per year)',
        xaxis = list(title = 'Year'),
        yaxis = list(title = 'Total Men Admissions (VD cases)'),
        legend = list(orientation = 'h')
      )
  })
  
  # ---------------------
  # Animated Timeline Map Outputs
  # ---------------------
  # Initial map render
  output$animated_timeline_map <- renderLeaflet({
    leaflet() %>% 
      addTiles() %>%
      setView(lng = 78.9629, lat = 20.5937, zoom = 5) %>%  # Center on India
      addLegend(
        position = "bottomright",
        colors = c('#d62728', '#ff7f0e', '#ffbb78', '#c7e9b4', '#cccccc'),
        labels = c('High (>20%)', 'Medium (10-20%)', 'Low (5-10%)', 'Minimal (<5%)', 'No Data'),
        title = "Punishment Rate",
        opacity = 0.7
      )
  })
  
  # Update markers when year changes
  observe({
    st <- stations_df()
    corr <- correlation_data()
    
    req(nrow(st) > 0, nrow(corr) > 0, input$timeline_year)
    
    # Detect lat/lon columns
    lat_col <- 'latitude'; lon_col <- 'longitude'
    if (all(c('lat','lon') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lon' }
    if (all(c('lat','lng') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lng' }
    
    st2 <- st %>% 
      dplyr::filter(!is.na(.data[[lat_col]]), !is.na(.data[[lon_col]])) %>%
      dplyr::mutate(lat = as.numeric(.data[[lat_col]]), lon = as.numeric(.data[[lon_col]])) %>%
      dplyr::filter(lat <= 90, lat >= -90, lon <= 180, lon >= -180)
    
    # Filter correlation data by selected year
    year_sel <- input$timeline_year
    corr_year <- corr %>% dplyr::filter(year == year_sel)
    
    # Ensure a common 'station' key exists in stations data
    if (!"station" %in% names(st2) && "name" %in% names(st2)) {
      st2 <- dplyr::rename(st2, station = name)
    }
    # Build robust join keys based on available columns
    join_keys <- c("station" = "station")
    if ("region" %in% names(st2) && "region" %in% names(corr_year)) join_keys <- c(join_keys, "region" = "region")
    if ("country" %in% names(st2) && "country" %in% names(corr_year)) join_keys <- c(join_keys, "country" = "country")
    # Join with stations
    map_data <- st2 %>% dplyr::left_join(corr_year, by = join_keys)
    
    req(nrow(map_data) > 0)
    
    # Scale circle size by registered women
    map_data <- map_data %>%
      dplyr::mutate(
        circle_size = sqrt(pmax(total_avg_registered, 0, na.rm = TRUE)) * 2,
        circle_size = ifelse(is.na(circle_size) | circle_size == 0, 3, pmin(circle_size, 20)),
        punishment_color = dplyr::case_when(
          is.na(punishment_rate) ~ '#cccccc',
          punishment_rate > 20 ~ '#d62728',
          punishment_rate > 10 ~ '#ff7f0e',
          punishment_rate > 5 ~ '#ffbb78',
          TRUE ~ '#c7e9b4'
        ),
        popup_text = paste0(
          "<b>", station, "</b><br>",
          "Year: ", year_sel, "<br>",
          "Region: ", ifelse(is.na(region), "Unknown", region), "<br>",
          "Registered Women: ", ifelse(is.na(total_avg_registered), "No data", round(total_avg_registered, 0)), "<br>",
          "Punishment Rate: ", ifelse(is.na(punishment_rate), "No data", paste0(round(punishment_rate, 1), "%")), "<br>",
          "Surveillance Index: ", ifelse(is.na(surveillance_index), "No data", round(surveillance_index, 1))
        )
      )
    
    leafletProxy("animated_timeline_map", data = map_data) %>%
      clearMarkers() %>%
      addCircleMarkers(
        ~lon, ~lat, 
        radius = ~circle_size,
        color = ~punishment_color,
        fillOpacity = 0.7,
        stroke = TRUE,
        weight = 1,
        popup = ~popup_text,
        layerId = ~station
      )
  })
  
  output$timeline_year_metrics <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    yearly_totals <- corr %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(
        total_registered = sum(total_avg_registered, na.rm = TRUE),
        total_fined = sum(total_fined, na.rm = TRUE),
        total_imprisoned = sum(total_imprisoned, na.rm = TRUE),
        .groups = 'drop'
      )
    
    validate(need(nrow(yearly_totals) > 0, "No yearly data"))
    
    p <- plot_ly(yearly_totals, x = ~year) %>%
      add_trace(y = ~total_registered, name = 'Registered Women', type = 'bar', marker = list(color = '#3498db')) %>%
      add_trace(y = ~total_fined, name = 'Fined', type = 'bar', marker = list(color = '#f39c12')) %>%
      add_trace(y = ~total_imprisoned, name = 'Imprisoned', type = 'bar', marker = list(color = '#e74c3c')) %>%
      layout(
        title = 'Year-over-Year Surveillance and Punishment',
        xaxis = list(title = 'Year'),
        yaxis = list(title = 'Count'),
        barmode = 'group'
      )
    p
  })
  
  # ---------------------
  # Disease Prevalence Map Outputs
  # ---------------------
  # Initial map render
  output$disease_prevalence_map <- renderLeaflet({
    leaflet() %>% 
      addTiles() %>%
      setView(lng = 78.9629, lat = 20.5937, zoom = 5)  # Center on India
  })
  
  # Update markers when metric selector changes
  observe({
    st <- stations_df()
    corr <- correlation_data()
    
    req(nrow(st) > 0, nrow(corr) > 0, input$disease_map_metric)
    
    # Detect lat/lon columns
    lat_col <- 'latitude'; lon_col <- 'longitude'
    if (all(c('lat','lon') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lon' }
    if (all(c('lat','lng') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lng' }
    
    st2 <- st %>% 
      dplyr::filter(!is.na(.data[[lat_col]]), !is.na(.data[[lon_col]])) %>%
      dplyr::mutate(lat = as.numeric(.data[[lat_col]]), lon = as.numeric(.data[[lon_col]])) %>%
      dplyr::filter(lat <= 90, lat >= -90, lon <= 180, lon >= -180)
    
    # Aggregate disease data by station (across all years)
    disease_by_station <- corr %>%
      dplyr::group_by(station, region, country) %>%
      dplyr::summarise(
        total_diseases = sum(total_diseases, na.rm = TRUE),
        primary_syphilis_rate = mean(primary_syphilis_rate, na.rm = TRUE),
        secondary_syphilis_rate = mean(secondary_syphilis_rate, na.rm = TRUE),
        gonorrhoea_rate = mean(gonorrhoea_rate, na.rm = TRUE),
        troop_vd_rate = mean(troop_vd_rate, na.rm = TRUE),
        .groups = 'drop'
      )
    
    # Ensure a common 'station' key exists in stations data
    if (!"station" %in% names(st2) && "name" %in% names(st2)) {
      st2 <- dplyr::rename(st2, station = name)
    }
    # Build robust join keys based on available columns
    join_keys <- c("station" = "station")
    if ("region" %in% names(st2) && "region" %in% names(disease_by_station)) join_keys <- c(join_keys, "region" = "region")
    if ("country" %in% names(st2) && "country" %in% names(disease_by_station)) join_keys <- c(join_keys, "country" = "country")
    # Join with stations
    map_data <- st2 %>% dplyr::left_join(disease_by_station, by = join_keys)
    
    req(nrow(map_data) > 0)
    
    # Color by selected metric
    metric <- input$disease_map_metric
    
    map_data <- map_data %>%
      dplyr::mutate(
        metric_value = .data[[metric]],
        popup_text = paste0(
          "<b>", station, "</b><br>",
          "Region: ", ifelse(is.na(region), "Unknown", region), "<br>",
          "Total Diseases: ", ifelse(is.na(total_diseases), "No data", round(total_diseases, 0)), "<br>",
          "Primary Syphilis Rate: ", ifelse(is.na(primary_syphilis_rate), "No data", paste0(round(primary_syphilis_rate, 1), "%")), "<br>",
          "Secondary Syphilis Rate: ", ifelse(is.na(secondary_syphilis_rate), "No data", paste0(round(secondary_syphilis_rate, 1), "%")), "<br>",
          "Gonorrhoea Rate: ", ifelse(is.na(gonorrhoea_rate), "No data", paste0(round(gonorrhoea_rate, 1), "%")), "<br>",
          "Troop VD Rate: ", ifelse(is.na(troop_vd_rate), "No data", paste0(round(troop_vd_rate, 1), "%"))
        )
      )
    
    # Create color palette
    pal <- colorNumeric(palette = "YlOrRd", domain = map_data$metric_value, na.color = "#cccccc")
    
    leafletProxy("disease_prevalence_map", data = map_data) %>%
      clearMarkers() %>%
      clearControls() %>%
      addCircleMarkers(
        ~lon, ~lat, 
        radius = 8,
        color = ~pal(metric_value),
        fillOpacity = 0.8,
        stroke = TRUE,
        weight = 1,
        popup = ~popup_text,
        layerId = ~station
      ) %>%
      addLegend(
        position = "bottomright",
        pal = pal,
        values = ~metric_value,
        title = "Disease Metric",
        opacity = 0.8,
        layerId = "disease_legend"
      )
  })
  
  output$disease_comparison_women <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    disease_totals <- corr %>%
      dplyr::summarise(
        `Primary Syphilis` = sum(primary_syphilis_women, na.rm = TRUE),
        `Secondary Syphilis` = sum(secondary_syphilis_women, na.rm = TRUE),
        Gonorrhoea = sum(gonorrhoea_women, na.rm = TRUE),
        Leucorrhoea = sum(leucorrhoea_women, na.rm = TRUE)
      ) %>%
      tidyr::pivot_longer(everything(), names_to = "Disease", values_to = "Cases")
    
    plot_ly(disease_totals, labels = ~Disease, values = ~Cases, type = 'pie',
            textinfo = 'label+percent',
            marker = list(colors = c('#e74c3c', '#c0392b', '#e67e22', '#f39c12'))) %>%
      layout(title = 'Disease Distribution in Women')
  })
  
  output$disease_comparison_troops <- renderPlotly({
    corr <- correlation_data()
    validate(need(nrow(corr) > 0, "No correlation data available"))
    
    disease_totals <- corr %>%
      dplyr::summarise(
        `Primary Syphilis` = sum(primary_syphilis_troops, na.rm = TRUE),
        `Secondary Syphilis` = sum(secondary_syphilis_troops, na.rm = TRUE),
        Gonorrhoea = sum(gonorrhoea_troops, na.rm = TRUE)
      ) %>%
      tidyr::pivot_longer(everything(), names_to = "Disease", values_to = "Cases")
    
    plot_ly(disease_totals, labels = ~Disease, values = ~Cases, type = 'pie',
            textinfo = 'label+percent',
            marker = list(colors = c('#3498db', '#2980b9', '#1abc9c'))) %>%
      layout(title = 'VD Distribution in Troops')
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
