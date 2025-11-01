library(shiny)
library(DBI)
library(RSQLite)
library(DT)

# Connect to database
con <- dbConnect(RSQLite::SQLite(), "medical_lock_hospitals.db")

# Load data once at startup
hospital_ops <- dbGetQuery(con, "SELECT * FROM hospital_operations")
women_data <- dbGetQuery(con, "SELECT * FROM women_admission")
troops_data <- dbGetQuery(con, "SELECT * FROM troops")
stations_data <- dbGetQuery(con, "SELECT * FROM stations")

dbDisconnect(con)

# Simple UI
ui <- fluidPage(
  titlePanel("Medical Lock Hospitals - Data Explorer"),
  
  tabsetPanel(
    tabPanel("Data Overview",
      h3("Database Summary"),
      p("Your data has been successfully loaded:"),
      tags$ul(
        tags$li(paste("Hospital Operations:", nrow(hospital_ops), "records")),
        tags$li(paste("Women Admission:", nrow(women_data), "records")),
        tags$li(paste("Troops:", nrow(troops_data), "records")),
        tags$li(paste("Stations:", nrow(stations_data), "records"))
      ),
      hr(),
      h4("Sample: Hospital Operations (first 10 rows)"),
      tableOutput("sample_table")
    ),
    
    tabPanel("Hospital Operations",
      h3("Hospital Operations Data"),
      DT::dataTableOutput("ops_table")
    ),
    
    tabPanel("Women Admission",
      h3("Women Admission Data"),
      DT::dataTableOutput("women_table")
    ),
    
    tabPanel("Troops",
      h3("Troops Data"),
      DT::dataTableOutput("troops_table")
    ),
    
    tabPanel("Stations",
      h3("Stations Data"),
      DT::dataTableOutput("stations_table")
    )
  )
)

# Simple server
server <- function(input, output, session) {
  
  output$sample_table <- renderTable({
    head(hospital_ops, 10)
  })
  
  output$ops_table <- DT::renderDataTable({
    DT::datatable(hospital_ops, options = list(pageLength = 25, scrollX = TRUE))
  })
  
  output$women_table <- DT::renderDataTable({
    DT::datatable(women_data, options = list(pageLength = 25, scrollX = TRUE))
  })
  
  output$troops_table <- DT::renderDataTable({
    DT::datatable(troops_data, options = list(pageLength = 25, scrollX = TRUE))
  })
  
  output$stations_table <- DT::renderDataTable({
    DT::datatable(stations_data, options = list(pageLength = 25, scrollX = TRUE))
  })
}

shinyApp(ui = ui, server = server)
