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
            title = "Data Tables - View & Edit", status = "primary", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(6,
                selectInput("table_select", "Choose Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_data", "troop_data", "hospital_operations"),
                  selected = "documents"
                )
              ),
              column(6,
                br(),
                actionButton("add_record", "Add New Record", class = "btn-success"),
                actionButton("refresh_table", "Refresh", class = "btn-info")
              )
            ),
            br(),
            DT::dataTableOutput("data_table"),
            br(),
            # Edit Record Panel
            conditionalPanel(
              condition = "input.data_table_rows_selected.length > 0",
              box(
                title = "Edit Selected Record", status = "warning", solidHeader = TRUE,
                width = 12,
                uiOutput("edit_form"),
                br(),
                actionButton("save_record", "Save Changes", class = "btn-primary"),
                actionButton("delete_record", "Delete Record", class = "btn-danger"),
                actionButton("cancel_edit", "Cancel", class = "btn-secondary")
              )
            )
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
                             "women_data", "troop_data", "hospital_operations")
                ),
                actionButton("find_duplicates", "Find Duplicates", class = "btn-warning"),
                br(), br(),
                DT::dataTableOutput("duplicates_table")
              ),
              
              tabPanel("Data Validation",
                br(),
                selectInput("validate_table_select", "Select Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_data", "troop_data", "hospital_operations")
                ),
                actionButton("validate_data", "Validate Data", class = "btn-info"),
                br(), br(),
                verbatimTextOutput("validation_results")
              ),
              
              tabPanel("Filter & Search",
                br(),
                selectInput("filter_table_select", "Select Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_data", "troop_data", "hospital_operations")
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
                             "women_data", "troop_data", "hospital_operations")
                ),
                selectInput("export_format", "Export Format:",
                  choices = c("CSV", "Excel", "JSON")
                ),
                actionButton("export_data", "Export Data", class = "btn-success")
              ),
              column(6,
                h4("Custom Query Export"),
                textAreaInput("custom_query", "Enter SQL Query:", 
                  placeholder = "SELECT * FROM women_data WHERE year > 1880",
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
    valueBox(count, "Documents", icon = icon("file-alt"), color = "primary")
  })
  
  output$total_stations <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM stations")$count
    valueBox(count, "Stations", icon = icon("map-marker-alt"), color = "success")
  })
  
  output$total_women_records <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM women_data")$count
    valueBox(count, "Women Records", icon = icon("female"), color = "info")
  })
  
  output$total_troop_records <- renderValueBox({
    count <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM troop_data")$count
    valueBox(count, "Troop Records", icon = icon("users"), color = "warning")
  })
  
  # Data Quality Summary
  output$quality_summary <- DT::renderDataTable({
    tables <- c("documents", "stations", "station_reports", "women_data", "troop_data", "hospital_operations")
    quality_data <- data.frame(
      Table = tables,
      Total_Records = sapply(tables, function(t) {
        dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
      }),
      Complete_Records = sapply(tables, function(t) {
        # Count records with no NULL values in key columns
        if (t == "documents") {
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL AND source_name IS NOT NULL"))$count
        } else if (t == "stations") {
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE name IS NOT NULL"))$count
        } else {
          dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE unique_id IS NOT NULL OR hid IS NOT NULL"))$count
        }
      })
    )
    quality_data$Completeness <- round(quality_data$Complete_Records / quality_data$Total_Records * 100, 1)
    quality_data
  }, options = list(pageLength = 6, dom = 't'))
  
  # Missing Data Plot
  output$missing_data_plot <- renderPlotly({
    tables <- c("documents", "stations", "station_reports", "women_data", "troop_data", "hospital_operations")
    missing_data <- data.frame(
      Table = tables,
      Missing_Percentage = sapply(tables, function(t) {
        # Calculate percentage of records with missing key data
        total <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
        if (t == "documents") {
          complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL AND source_name IS NOT NULL"))$count
        } else if (t == "stations") {
          complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE name IS NOT NULL"))$count
        } else {
          complete <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE unique_id IS NOT NULL OR hid IS NOT NULL"))$count
        }
        round((total - complete) / total * 100, 1)
      })
    )
    
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
    DT::datatable(data, 
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
      ), 
      extensions = 'Buttons',
      selection = 'single'
    )
  })
  
  # Get foreign key relationships
  get_foreign_keys <- function(table_name) {
    fk_info <- list()
    
    if (table_name == "station_reports") {
      fk_info$doc_id <- dbGetQuery(conn(), "SELECT doc_id, source_name FROM documents ORDER BY source_name")
      fk_info$station_id <- dbGetQuery(conn(), "SELECT station_id, name FROM stations ORDER BY name")
    } else if (table_name == "women_data") {
      fk_info$doc_id <- dbGetQuery(conn(), "SELECT doc_id, source_name FROM documents ORDER BY source_name")
    } else if (table_name == "troop_data") {
      fk_info$doc_id <- dbGetQuery(conn(), "SELECT doc_id, source_name FROM documents ORDER BY source_name")
    } else if (table_name == "hospital_operations") {
      fk_info$doc_id <- dbGetQuery(conn(), "SELECT doc_id, source_name FROM documents ORDER BY source_name")
    }
    
    return(fk_info)
  }
  
  # Get table schema
  get_table_schema <- function(table_name) {
    schema <- dbGetQuery(conn(), paste("PRAGMA table_info(", table_name, ")"))
    return(schema)
  }
  
  # Edit form UI
  output$edit_form <- renderUI({
    if (length(input$data_table_rows_selected) == 0) return(NULL)
    
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    fk_data <- get_foreign_keys(table_name)
    
    # Get current record data
    query <- paste("SELECT * FROM", table_name, "LIMIT 1 OFFSET", input$data_table_rows_selected - 1)
    current_data <- dbGetQuery(conn(), query)
    
    # Create form inputs
    form_inputs <- list()
    
    for (i in 1:nrow(schema)) {
      col_name <- schema$name[i]
      col_type <- schema$type[i]
      is_pk <- schema$pk[i] == 1
      current_value <- current_data[[col_name]]
      
      # Skip auto-increment primary keys
      if (is_pk && col_type == "INTEGER") {
        next
      }
      
      # Handle foreign key lookups
      if (col_name %in% names(fk_data)) {
        choices <- setNames(fk_data[[col_name]][[1]], fk_data[[col_name]][[2]])
        form_inputs[[length(form_inputs) + 1]] <- selectInput(
          paste0("edit_", col_name),
          paste0(col_name, " (", names(fk_data)[which(names(fk_data) == col_name)], "):"),
          choices = c("", choices),
          selected = current_value
        )
      } else {
        # Regular input based on column type
        if (col_type == "INTEGER") {
          form_inputs[[length(form_inputs) + 1]] <- numericInput(
            paste0("edit_", col_name),
            paste0(col_name, ":"),
            value = ifelse(is.na(current_value), 0, current_value),
            min = 0
          )
        } else if (col_type == "REAL") {
          form_inputs[[length(form_inputs) + 1]] <- numericInput(
            paste0("edit_", col_name),
            paste0(col_name, ":"),
            value = ifelse(is.na(current_value), 0, current_value),
            step = 0.01
          )
        } else {
          form_inputs[[length(form_inputs) + 1]] <- textInput(
            paste0("edit_", col_name),
            paste0(col_name, ":"),
            value = ifelse(is.na(current_value), "", current_value)
          )
        }
      }
    }
    
    # Arrange inputs in columns
    fluidRow(
      column(6, form_inputs[1:ceiling(length(form_inputs)/2)]),
      column(6, form_inputs[(ceiling(length(form_inputs)/2)+1):length(form_inputs)])
    )
  })
  
  # Add new record
  observeEvent(input$add_record, {
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    fk_data <- get_foreign_keys(table_name)
    
    # Create form inputs for new record
    form_inputs <- list()
    
    for (i in 1:nrow(schema)) {
      col_name <- schema$name[i]
      col_type <- schema$type[i]
      is_pk <- schema$pk[i] == 1
      
      # Skip auto-increment primary keys
      if (is_pk && col_type == "INTEGER") {
        next
      }
      
      # Handle foreign key lookups
      if (col_name %in% names(fk_data)) {
        choices <- setNames(fk_data[[col_name]][[1]], fk_data[[col_name]][[2]])
        form_inputs[[length(form_inputs) + 1]] <- selectInput(
          paste0("new_", col_name),
          paste0(col_name, " (", names(fk_data)[which(names(fk_data) == col_name)], "):"),
          choices = c("", choices),
          selected = ""
        )
      } else {
        # Regular input based on column type
        if (col_type == "INTEGER") {
          form_inputs[[length(form_inputs) + 1]] <- numericInput(
            paste0("new_", col_name),
            paste0(col_name, ":"),
            value = 0,
            min = 0
          )
        } else if (col_type == "REAL") {
          form_inputs[[length(form_inputs) + 1]] <- numericInput(
            paste0("new_", col_name),
            paste0(col_name, ":"),
            value = 0,
            step = 0.01
          )
        } else {
          form_inputs[[length(form_inputs) + 1]] <- textInput(
            paste0("new_", col_name),
            paste0(col_name, ":"),
            value = ""
          )
        }
      }
    }
    
    # Show modal dialog for new record
    showModal(modalDialog(
      title = paste("Add New Record to", table_name),
      fluidRow(
        column(6, form_inputs[1:ceiling(length(form_inputs)/2)]),
        column(6, form_inputs[(ceiling(length(form_inputs)/2)+1):length(form_inputs)])
      ),
      footer = tagList(
        actionButton("save_new_record", "Save", class = "btn-primary"),
        modalButton("Cancel")
      ),
      size = "l"
    ))
  })
  
  # Save new record
  observeEvent(input$save_new_record, {
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    
    # Collect form data
    values <- list()
    columns <- c()
    
    for (i in 1:nrow(schema)) {
      col_name <- schema$name[i]
      col_type <- schema$type[i]
      is_pk <- schema$pk[i] == 1
      
      # Skip auto-increment primary keys
      if (is_pk && col_type == "INTEGER") {
        next
      }
      
      input_name <- paste0("new_", col_name)
      value <- input[[input_name]]
      
      if (!is.null(value) && value != "") {
        columns <- c(columns, col_name)
        values <- c(values, value)
      }
    }
    
    if (length(values) > 0) {
      # Build INSERT query
      placeholders <- paste(rep("?", length(values)), collapse = ", ")
      query <- paste("INSERT INTO", table_name, "(", paste(columns, collapse = ", "), ") VALUES (", placeholders, ")")
      
      tryCatch({
        dbExecute(conn(), query, params = values)
        removeModal()
        showNotification("Record added successfully!", type = "message")
      }, error = function(e) {
        showNotification(paste("Error adding record:", e$message), type = "error")
      })
    }
  })
  
  # Save edited record
  observeEvent(input$save_record, {
    if (length(input$data_table_rows_selected) == 0) return(NULL)
    
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    
    # Get current record data to identify primary key
    query <- paste("SELECT * FROM", table_name, "LIMIT 1 OFFSET", input$data_table_rows_selected - 1)
    current_data <- dbGetQuery(conn(), query)
    
    # Collect form data
    values <- list()
    columns <- c()
    pk_column <- NULL
    pk_value <- NULL
    
    for (i in 1:nrow(schema)) {
      col_name <- schema$name[i]
      col_type <- schema$type[i]
      is_pk <- schema$pk[i] == 1
      
      if (is_pk) {
        pk_column <- col_name
        pk_value <- current_data[[col_name]]
        next
      }
      
      input_name <- paste0("edit_", col_name)
      value <- input[[input_name]]
      
      if (!is.null(value)) {
        columns <- c(columns, col_name)
        values <- c(values, value)
      }
    }
    
    if (length(values) > 0 && !is.null(pk_column)) {
      # Build UPDATE query
      set_clause <- paste(paste(columns, "= ?", collapse = ", "))
      query <- paste("UPDATE", table_name, "SET", set_clause, "WHERE", pk_column, "= ?")
      
      tryCatch({
        dbExecute(conn(), query, params = c(values, pk_value))
        showNotification("Record updated successfully!", type = "message")
      }, error = function(e) {
        showNotification(paste("Error updating record:", e$message), type = "error")
      })
    }
  })
  
  # Delete record
  observeEvent(input$delete_record, {
    if (length(input$data_table_rows_selected) == 0) return(NULL)
    
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    
    # Get current record data to identify primary key
    query <- paste("SELECT * FROM", table_name, "LIMIT 1 OFFSET", input$data_table_rows_selected - 1)
    current_data <- dbGetQuery(conn(), query)
    
    # Find primary key
    pk_column <- schema$name[schema$pk == 1][1]
    pk_value <- current_data[[pk_column]]
    
    if (!is.null(pk_column) && !is.null(pk_value)) {
      # Show confirmation dialog
      showModal(modalDialog(
        title = "Confirm Deletion",
        paste("Are you sure you want to delete this record from", table_name, "?"),
        footer = tagList(
          actionButton("confirm_delete", "Delete", class = "btn-danger"),
          modalButton("Cancel")
        )
      ))
    }
  })
  
  # Confirm delete
  observeEvent(input$confirm_delete, {
    if (length(input$data_table_rows_selected) == 0) return(NULL)
    
    table_name <- input$table_select
    schema <- get_table_schema(table_name)
    
    # Get current record data to identify primary key
    query <- paste("SELECT * FROM", table_name, "LIMIT 1 OFFSET", input$data_table_rows_selected - 1)
    current_data <- dbGetQuery(conn(), query)
    
    # Find primary key
    pk_column <- schema$name[schema$pk == 1][1]
    pk_value <- current_data[[pk_column]]
    
    if (!is.null(pk_column) && !is.null(pk_value)) {
      query <- paste("DELETE FROM", table_name, "WHERE", pk_column, "= ?")
      
      tryCatch({
        dbExecute(conn(), query, params = pk_value)
        removeModal()
        showNotification("Record deleted successfully!", type = "message")
      }, error = function(e) {
        showNotification(paste("Error deleting record:", e$message), type = "error")
      })
    }
  })
  
  # Cancel edit
  observeEvent(input$cancel_edit, {
    # Clear selection
    DT::dataTableProxy("data_table") %>% DT::selectRows(NULL)
  })
  
  # Refresh table
  observeEvent(input$refresh_table, {
    # Trigger table refresh
    DT::dataTableProxy("data_table") %>% DT::reloadData()
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
                     ifelse(table_name %in% c("women_data", "troop_data"), "unique_id", "hid"), ")")
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
      data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM women_data WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      p <- ggplot(data, aes(x = year, y = count)) +
        geom_line(color = "purple", size = 1) +
        geom_point(color = "purple", size = 2) +
        theme_minimal() +
        labs(title = "Women Data Records by Year", x = "Year", y = "Number of Records")
    } else if (input$time_plot_type == "Troop Data by Year") {
      data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM troop_data WHERE year IS NOT NULL GROUP BY year ORDER BY year")
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
      women_data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM women_data WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      troop_data <- dbGetQuery(conn(), "SELECT year, COUNT(*) as count FROM troop_data WHERE year IS NOT NULL GROUP BY year ORDER BY year")
      
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
      p <- ggplot(data, aes(x = reorder(region, count), y = count, fill = region)) +
        geom_bar(stat = "identity") +
        coord_flip() +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(title = "Stations by Region", x = "Region", y = "Number of Stations")
    } else if (input$geo_plot_type == "Operations by Country") {
      data <- dbGetQuery(conn(), "SELECT country, COUNT(*) as count FROM hospital_operations WHERE country IS NOT NULL GROUP BY country ORDER BY count DESC")
      p <- ggplot(data, aes(x = reorder(country, count), y = count, fill = country)) +
        geom_bar(stat = "identity") +
        coord_flip() +
        theme_minimal() +
        theme(legend.position = "none") +
        labs(title = "Hospital Operations by Country", x = "Country", y = "Number of Operations")
    } else {
      # Regional Distribution
      data <- dbGetQuery(conn(), "SELECT region, COUNT(*) as count FROM stations WHERE region IS NOT NULL GROUP BY region ORDER BY count DESC")
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
        FROM women_data w 
        LEFT JOIN troop_data t ON w.station = t.station AND w.year = t.year 
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
        FROM women_data 
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
