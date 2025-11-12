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
library(stringr)
library(networkD3)
library(sf)  # For reading shapefiles
library(rnaturalearth)  # For country boundaries
library(rnaturalearthdata)  # Country boundary data
## Optional: Excel ingestion for DS_Dataset (used if available)
# We'll use readxl lazily via requireNamespace in server to avoid hard dependency at load time.

# Ensure images directory exists and serve as /images
if (!dir.exists("content/images")) {
  dir.create("content/images", recursive = TRUE, showWarnings = FALSE)
}
shiny::addResourcePath("images", "content/images")

# Toggle to disable heavy analytics and long-running observers while debugging UI
# Set to TRUE to enable Safe Mode (shows map/tables but skips heavy analyses)
SAFE_MODE <- TRUE

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
  dashboardHeader(title = "Governing Diseases and Sexuality in Colonial India"),
  
  dashboardSidebar(
    sidebarMenu(id = "sidebar",
      menuItem("Story", tabName = "story", icon = icon("book-open")),
      menuItem("Interactive Map", tabName = "map", icon = icon("map")),
      menuItem("Data Tables", tabName = "tables", icon = icon("table")),
      menuItem("Data Cleaning", tabName = "cleaning", icon = icon("broom")),
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
        /* Hide Shiny busy overlay and modal backdrop to avoid dimming during long renders (temporary) */
        .shiny-busy, .shiny-busy-indicator, .shiny-busy-overlay, .shiny-busy-container { display: none !important; visibility: hidden !important; }
        .modal-backdrop { display: none !important; }
      "))
    ),
    
    tabItems(
      # Story Tab - Scrollytelling Narrative (combined with Data Overview)
      tabItem(tabName = "story",
        tags$head(
          tags$style(HTML("
            .story-section {
              min-height: 100vh;
              padding: 60px 20px;
              display: flex;
              align-items: center;
              border-bottom: 1px solid #e0e0e0;
            }
            .story-content {
              max-width: 900px;
              margin: 0 auto;
            }
            .story-title {
              font-size: 2.5em;
              font-weight: 300;
              margin-bottom: 20px;
              color: #2c3e50;
            }
            .story-text {
              font-size: 1.2em;
              line-height: 1.8;
              color: #34495e;
              margin-bottom: 30px;
            }
            .story-stat {
              font-size: 3em;
              font-weight: bold;
              color: #e74c3c;
              margin: 20px 0;
            }
            .story-caption {
              font-size: 0.9em;
              color: #7f8c8d;
              font-style: italic;
            }
            .viz-container {
              margin: 40px 0;
              background: white;
              padding: 20px;
              border-radius: 8px;
              box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
          "))
        ),
        
        # Section 1: Introduction - About the Dataset
        div(class = "story-section", style = "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;",
          div(class = "story-content",
            h1(class = "story-title", style = "color: white;", "Governing Diseases and Sexuality in Colonial India"),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "This dataset is built from nineteenth-century Lock Hospital Reports and Sanitary Commissioner's Reports produced under British rule in India. These records were part of a larger administrative effort to monitor women categorized as \"registered prostitutes\" under the Contagious Diseases Acts. Through these reports, the colonial state sought to control the spread of venereal disease among soldiers by transforming women's bodies into objects of record and inspection."
            ),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "The figures contained in these documents—women admitted, discharged, fined, or imprisoned; soldiers treated for disease; hospitals opened or closed—offer insight into how public health became a language of governance. What appeared as medical management was deeply tied to moral discipline and imperial control."
            ),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "Each entry in this dataset reflects the bureaucratic structure of the colonial state: the staffing of hospitals, the geography of cantonments, and the regular counting of \"registered\" and \"unregistered\" women. Taken together, these numbers allow us to see how the colonial government converted everyday life into data, turning acts of care into mechanisms of surveillance."
            ),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "Rather than treating these figures as neutral statistics, this project reads them as evidence of how medicine, morality, and governance became intertwined in the making of empire."
            )
          )
        ),
        
        # Section 2: The Scale - Database Summary
        div(class = "story-section",
          div(class = "story-content",
            h2(class = "story-title", "A System Across an Empire"),
            p(class = "story-text",
              "Lock Hospitals operated across British India, from Bengal to Burma, creating a vast infrastructure of medical control. Each station became a site where military necessity intersected with moral regulation."
            ),
            div(class = "viz-container",
              uiOutput("story_total_stats")
            ),
            div(class = "viz-container",
              leafletOutput("story_map_overview", height = 500)
            ),
            br(),
            div(class = "viz-container",
              h4("Data Quality Summary", style = "margin-bottom: 20px; color: #2c3e50;"),
              DT::dataTableOutput("quality_summary")
            )
          )
        ),
        
        # Section 3: From the Archives - Images
        div(class = "story-section", style = "background: #f8f9fa;",
          div(class = "story-content",
            h2(class = "story-title", "From the Archives"),
            p(class = "story-text",
              "These selections from nineteenth-century reports and illustrations offer a glimpse into the visual culture of colonial medical surveillance. Each document reflects how the state rendered women's bodies as objects of study and control."
            ),
            div(class = "viz-container",
              fileInput("archive_image_upload", "Upload images (JPG/PNG/WebP)", multiple = TRUE,
                        accept = c("image/png","image/jpeg","image/webp","image/gif")),
              helpText("You can also place files directly in content/images/."),
              uiOutput("overview_images")
            )
          )
        ),
        
        # Section 4: The Timeline - Acts of Empire
        div(class = "story-section",
          div(class = "story-content",
            h2(class = "story-title", "Acts of Empire"),
            p(class = "story-text",
              "Three major Acts structured this system of control:"
            ),
            div(class = "viz-container",
              htmlOutput("story_acts_timeline")
            ),
            p(class = "story-text",
              "Each Act expanded the state's power to inspect, register, and punish women suspected of spreading disease."
            )
          )
        ),
        
        # Section 5: Conclusion - Reading the Archive
        div(class = "story-section", style = "background: #2c3e50; color: white; min-height: 80vh;",
          div(class = "story-content",
            h2(class = "story-title", style = "color: white;", "Reading the Archive"),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "These numbers—women registered, fined, examined—were never neutral. They represent acts of violence made routine through bureaucracy."
            ),
            p(class = "story-text", style = "color: rgba(255,255,255,0.95);",
              "By reading these records critically, we can see how colonial medicine became a tool of empire, and how women's bodies became sites of state control."
            ),
            br(), br(),
            actionButton("explore_data_btn", "Explore the Full Dataset", 
                        class = "btn-lg btn-primary",
                        style = "padding: 15px 40px; font-size: 1.2em;",
                        onclick = "Shiny.setInputValue('switch_to_tables', Math.random())")
          )
        )
      ),
      
      # Interactive Map Tab
      tabItem(tabName = "map",
        fluidRow(
          box(
            title = "Lock Hospital Locations",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            height = "700px",
            leafletOutput("map", height = "500px"),
            absolutePanel(
              id = "map_controls",
              class = "panel panel-default",
              fixed = TRUE,
              draggable = TRUE,
              top = 60,
              left = "auto",
              right = 20,
              bottom = "auto",
              width = 330,
              height = "auto",
              style = "padding: 15px; background: white; opacity: 0.95;",
              
              # Year range slider - select single year or range
              sliderInput("year_slider", "Select Year(s):",
                min = 1873, max = 1890,
                value = c(1873, 1873),  # Start with single year (both values same)
                step = 1,
                sep = "",
                dragRange = TRUE,  # Allow dragging the range
                animate = animationOptions(interval = 1500)
              ),
              helpText("💡 Drag one handle for a single year, or both handles to select a range.", 
                       style = "font-size: 10px; color: #7f8c8d; margin-top: -5px; margin-bottom: 10px;"),
              
              # Act checkboxes - filter which acts to display
              checkboxGroupInput("acts", "Filter by Acts:",
                choices = list(
                  "Act XXII of 1864" = "Act XXII of 1864",
                  "Act XII of 1864" = "Act XII of 1864",
                  "Act XIV of 1868" = "Act XIV of 1868",
                  "Act III of 1880" = "Act III of 1880",
                  "Voluntary System" = "Voluntary System"
                ),
                selected = c("Act XXII of 1864", "Act XII of 1864", "Act XIV of 1868", "Act III of 1880", "Voluntary System")
              ),
              
              hr(style = "margin: 15px 0;"),
              
              # Railway overlay toggle
              checkboxInput("show_railways", "Show Railway Lines & Stations", value = TRUE),
              
              # Legend
              htmlOutput("map_legend")
            )
          )
        ),
        # Timeline visualization
        fluidRow(
          box(
            title = "Women Admissions Over Time",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            height = "400px",
            plotlyOutput("women_timeline", height = "300px")
          )
        )
      ),
      
      # Data Tables Tab
      tabItem(tabName = "tables",
        fluidRow(
          box(
            title = "Select Table to View & Edit", status = "primary", solidHeader = TRUE,
            width = 12,
            fluidRow(
              column(6,
                selectInput("table_select", "Choose Table:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations"),
                  selected = "documents"
                )
              ),
              column(6,
                div(style = "margin-top: 25px;",
                  actionButton("delete_row_btn", "Delete Selected Row", icon = icon("trash"), class = "btn-danger"),
                  actionButton("add_row_btn", "Add New Row", icon = icon("plus"), class = "btn-success")
                )
              )
            ),
            br(),
            helpText("Click any cell to edit. Changes save automatically. Select a row and click 'Delete' to remove it."),
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
      
      # Q1: Medicalization & Administrative Categories
      tabItem(tabName = "q1_medicalization",
        fluidRow(
          box(
            title = "How did the colonial state medicalize sexuality and transform women's bodies into administrative categories?", 
            status = "primary", solidHeader = TRUE, width = 12, collapsible = FALSE,
            div(style = "background: #e8f4f8; padding: 20px; margin-bottom: 25px; border-left: 5px solid #3498db; border-radius: 4px;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.7; color: #2c3e50;",
                "These visualizations reveal the bureaucratic machinery that converted women into data points. ",
                "Look for temporal patterns around legislative moments (1864, 1868, 1880), spatial concentration in military zones, ",
                "and diagnostic category shifts that expose classificatory regimes rather than neutral disease counts."
              )
            )
          )
        ),
        
        fluidRow(
          box(title = "Temporal Patterns", status = "info", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Track how administrative practices intensified over time. Spikes may reflect new inspection orders, standardized returns, or officer transfers—not changes 'on the ground.'"),
            fluidRow(
              column(6, plotlyOutput("med_temporal_women_added", height = 400)),
              column(6, plotlyOutput("med_temporal_avg_registered", height = 400))
            )
          )
        ),
        
        fluidRow(
          box(title = "Surveillance Index Over Time", status = "primary", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Dual-axis plot shows co-movement between military VD pressure and women's surveillance intensity. Read as policy responsivity, not simple causation."),
            plotlyOutput("correlation_dual_axis", height = 500),
            br(),
            h4("Normalized Metrics by Region"),
            DT::dataTableOutput("correlation_metrics_table")
          )
        )
      ),
      
      # Q2: Gendered Treatment Differences
      tabItem(tabName = "q2_gender",
        fluidRow(
          box(
            title = "How differently were men and women treated in these reports?", 
            status = "warning", solidHeader = TRUE, width = 12, collapsible = FALSE,
            div(style = "background: #fff9e6; padding: 20px; margin-bottom: 25px; border-left: 5px solid #f39c12; border-radius: 4px;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.7; color: #2c3e50;",
                "These visualizations expose structural asymmetry: women were policed and punished through compulsory exams; ",
                "men were treated as patients whose health mattered for imperial strength. Compare not just totals but intensities and ratios."
              )
            )
          )
        ),
        
        fluidRow(
          box(title = "The Surveillance Pipeline: Military Disease → Regulation → Women's Control", 
              status = "info", solidHeader = TRUE, width = 9,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Interactive Sankey flow shown in percentages: share of military VD cases across Acts, each Act's share of women's admissions, and the percent of women registered out of those admitted. Use the timeline to filter by Act period."),
            fluidRow(
              column(12,
                sliderInput("pipeline_years", "Timeline (Filter by Years):",
                           min = 1860, max = 1890, value = c(1860, 1890),
                           step = 1, sep = "", width = "100%")
              )
            ),
            br(),
            sankeyNetworkOutput("med_surveillance_sankey", height = 550)
          ),
          box(title = "Contagious Diseases Acts Reference", status = "warning", solidHeader = TRUE, width = 3,
            div(style = "font-size: 0.9em; color: #2c3e50;",
              HTML("
                <h5 style='color:#e74c3c; margin-top:0;'>📜 Act XXII of 1864</h5>
                <p style='margin: 4px 0;'><strong>Period:</strong> 1864-1868</p>
                <p style='margin: 4px 0;'><strong>Key Clauses:</strong></p>
                <ul style='margin-top: 4px; padding-left: 18px; font-size: 0.85em;'>
                  <li>Compulsory registration of women near cantonments</li>
                  <li>Periodic medical examinations</li>
                  <li>Detention in Lock Hospitals if diseased</li>
                </ul>
                
                <h5 style='color:#f39c12; margin-top: 12px;'>📜 Act VI of 1868</h5>
                <p style='margin: 4px 0;'><strong>Period:</strong> 1868-1869</p>
                <p style='margin: 4px 0;'><strong>Expansion:</strong></p>
                <ul style='margin-top: 4px; padding-left: 18px; font-size: 0.85em;'>
                  <li>Extended to civil stations</li>
                  <li>Magistrate oversight committees</li>
                </ul>
                
                <h5 style='color:#9b59b6; margin-top: 12px;'>📜 Act XIV of 1868</h5>
                <p style='margin: 4px 0;'><strong>Period:</strong> 1868-1872</p>
                <p style='margin: 4px 0;'><strong>Consolidation:</strong></p>
                <ul style='margin-top: 4px; padding-left: 18px; font-size: 0.85em;'>
                  <li>Standardized procedures across presidencies</li>
                  <li>Enhanced police powers</li>
                </ul>
                
                <h5 style='color:#2c3e50; margin-top: 12px;'>📜 Act III of 1880</h5>
                <p style='margin: 4px 0;'><strong>Period:</strong> 1880-1888</p>
                <p style='margin: 4px 0;'><strong>Final Form:</strong></p>
                <ul style='margin-top: 4px; padding-left: 18px; font-size: 0.85em;'>
                  <li>Stricter enforcement</li>
                  <li>Punishment for non-attendance</li>
                  <li>Broader geographic scope</li>
                </ul>
                
                <hr style='margin: 12px 0; border-color: #bdc3c7;'>
                <p style='font-size: 0.8em; color: #7f8c8d; font-style: italic;'>
                  Hover over flows in the Sankey diagram to see station-level details and Act periods.
                </p>
              ")
            )
          )
        ),
        
        # Network analysis of what was recorded for men vs women
        fluidRow(
          box(title = "Network: What’s Recorded About Men (Troops)", status = "primary", solidHeader = TRUE, width = 6,
            p(style = "color:#7f8c8d;", "Each link width shows the percentage of troop records that contain a value for that field (filtered by the timeline above)."),
            forceNetworkOutput("med_men_network", height = 520)
          ),
          box(title = "Network: What’s Recorded About Women", status = "primary", solidHeader = TRUE, width = 6,
            p(style = "color:#7f8c8d;", "Each link width shows the percentage of women’s records that contain a value for that field (filtered by the timeline above)."),
            forceNetworkOutput("med_women_network", height = 520)
          )
        ),

        fluidRow(
          box(title = "Admissions by Region (Comparative)", status = "warning", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Compare yearly admissions across regions. Women: sum of disease cases (compulsory exams); Men: VD admissions (hospital records). Note the structural difference."),
            selectizeInput("admissions_regions", "Select Regions to Compare:", 
                          choices = NULL, multiple = TRUE, 
                          options = list(plugins = list("remove_button"))),
            br(),
            fluidRow(
              column(6, plotlyOutput("admissions_women_by_region", height = 450)),
              column(6, plotlyOutput("admissions_men_by_region", height = 450))
            )
          )
        )
      ),
      
      # Q3: Acts & Legal Geography
      tabItem(tabName = "q3_acts",
        fluidRow(
          box(
            title = "What Acts were implemented in which stations and why does it matter?", 
            status = "success", solidHeader = TRUE, width = 12, collapsible = FALSE,
            div(style = "background: #e8f8f5; padding: 20px; margin-bottom: 25px; border-left: 5px solid #27ae60; border-radius: 4px;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.7; color: #2c3e50;",
                "Implementation patterns show the geography of legality. Where Acts formalized coercion, surveillance intensified. ",
                "Pre/post comparisons reveal whether laws produced new practices or simply normalized existing control."
              )
            )
          )
        ),
        
        fluidRow(
          box(title = "Interactive Acts Implementation Map", status = "success", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Network visualization showing how Contagious Diseases Acts spread across stations. Use the slider to see temporal diffusion patterns. Lines connect stations adopting the same Act in the same year, revealing implementation networks."),
            helpText(style = "color: #e67e22; font-weight: bold;", 
                     "Note: Act III of 1880 appears from 1887 onwards; Voluntary System appears in 1890. Use the slider or filter to explore different Acts."),
            sliderInput("acts_year", "Year:", 
                        min = 1873, max = 1890, value = 1890, 
                        step = 1, animate = animationOptions(interval = 1000, loop = FALSE)),
            checkboxInput("show_network_lines", "Show Network Connections", value = TRUE),
            selectInput("network_act_filter", "Filter by Act (or show all):",
                       choices = c("All Acts" = "all"), selected = "all"),
            leafletOutput("acts_animated_map", height = 700),
            br(),
            h4("Acts Implementation Summary by Year"),
            plotlyOutput("acts_year_summary", height = 300)
          )
        )
      ),
      
      # Disease Analysis Tab
      tabItem(tabName = "disease_analysis",
        fluidRow(
          box(
            title = "Disease Patterns & Diagnostic Categories", 
            status = "info", solidHeader = TRUE, width = 12, collapsible = FALSE,
            div(style = "background: #f0f8ff; padding: 20px; margin-bottom: 25px; border-left: 5px solid #3498db; border-radius: 4px;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.7; color: #2c3e50;",
                "Disease categories are administrative constructs, not neutral medical facts. ",
                "Women's disease records derive from compulsory examinations; men's from hospital admissions. ",
                "Compare diagnostic patterns, geographic distributions, and institutional asymmetries in disease classification."
              )
            )
          )
        ),
        
        fluidRow(
          box(title = "Disease Categories Distribution", status = "info", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "These categories are administrative, not neutral epidemiology. Shifts in diagnostic labels can indicate inspection regime changes or diagnostic drift."),
            fluidRow(
              column(6, plotlyOutput("med_disease_pie", height = 450)),
              column(6, plotlyOutput("med_disease_bar", height = 450))
            )
          )
        ),
        
        fluidRow(
          box(title = "Disease Comparisons: Women vs Men", status = "primary", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Diagnostic categories were produced in unequal institutional settings. Women faced compulsory exams; male records reflect voluntary admissions."),
            fluidRow(
              column(6, plotlyOutput("disease_comparison_women", height = 450)),
              column(6, plotlyOutput("disease_comparison_troops", height = 450))
            )
          )
        ),
        
        fluidRow(
          box(title = "Disease Prevalence by Station (Geographic)", status = "primary", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Geographic distribution of disease categories across Lock Hospital stations."),
            selectInput("disease_map_metric", "Color stations by:",
                        choices = c("Total Disease Cases" = "total_diseases",
                                   "Primary Syphilis Rate" = "primary_syphilis_rate",
                                   "Secondary Syphilis Rate" = "secondary_syphilis_rate",
                                   "Gonorrhoea Rate" = "gonorrhoea_rate",
                                   "Troop VD Pressure" = "troop_vd_rate"),
                        selected = "total_diseases"),
            leafletOutput("disease_prevalence_map", height = 600)
          )
        )
      ),
      
      # Hospital Operations & Governance Tab
      tabItem(tabName = "hospital_ops",
        fluidRow(
          box(
            title = "How did the colonial state operationalize medical surveillance on the ground?", 
            status = "warning", solidHeader = TRUE, width = 12, collapsible = FALSE,
            div(style = "background: #fff9e6; padding: 20px; margin-bottom: 25px; border-left: 5px solid #f39c12; border-radius: 4px;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.7; color: #2c3e50;",
                "These visualizations reveal the administrative machinery behind surveillance: inspection regimes, ",
                "policing methods for unlicensed women, committee oversight structures, and punishment patterns. ",
                "Read these as evidence of bureaucratic intensity and local enforcement variations, not neutral hospital administration."
              )
            ),
            verbatimTextOutput("ops_debug_info")
          )
        ),
        
        fluidRow(
          box(title = "Inspection Regimes", status = "primary", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "How frequently were registered women inspected? Weekly inspections signal intensive surveillance; irregular patterns may indicate resistance, resource scarcity, or administrative breakdown."),
            fluidRow(
              column(6, plotlyOutput("ops_inspection_timeline", height = 400)),
              column(6, plotlyOutput("ops_inspection_by_region", height = 400))
            )
          )
        ),
        
        fluidRow(
          box(title = "Policing Unlicensed Women", status = "danger", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "How were 'unlicensed' (unregistered) women controlled? Police action was the primary method, supplemented by special constables and reward schemes."),
            fluidRow(
              column(6, plotlyOutput("ops_unlicensed_methods", height = 400)),
              column(6, plotlyOutput("ops_unlicensed_by_act", height = 400))
            )
          )
        ),
        
        fluidRow(
          box(title = "Administrative Oversight", status = "info", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Who supervised Lock Hospitals? Magistrates, formal committees, or subcommittees? Oversight structure reveals administrative hierarchy and local governance patterns."),
            fluidRow(
              column(6, plotlyOutput("ops_committee_distribution", height = 400)),
              column(6, plotlyOutput("ops_committee_by_region", height = 400))
            )
          )
        ),
        
        fluidRow(
          box(title = "Punishment & Resistance Indicators", status = "warning", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "Absentee punishments extracted from inspection notes reveal where and when women resisted compulsory examinations. High punishment rates indicate resistance; mentions of 'irregular attendance' signal administrative struggle."),
            fluidRow(
              column(6, plotlyOutput("ops_punishment_timeline", height = 400)),
              column(6, plotlyOutput("ops_punishment_by_station", height = 400))
            )
          )
        ),
        
        
        
        fluidRow(
          box(title = "Staff Role Keywords in Hospital Notes (Experimental Proxy)", status = "primary", solidHeader = TRUE, width = 12,
            p(style = "color: #7f8c8d; font-size: 1.05em;", 
              "⚠️ This is a rough text-mining proxy. We count role keywords in hospital operation notes (inspection reports, committee notes, remarks). ",
              strong("Male-coded roles:"), " surgeon, apothecary, doctor, medical officer, secretary. ",
              strong("Female-coded roles:"), " matron, nurse, midwife, ayah. ",
              "If no mentions appear, the notes may not reference staff explicitly or use different terminology."),
            fluidRow(
              column(6, plotlyOutput("ops_staff_mentions_timeline", height = 400)),
              column(6, plotlyOutput("ops_staff_mentions_by_region", height = 400))
            )
          )
        )
      ),
      
      # Summary Statistics Tab
      tabItem(tabName = "summary",
        fluidRow(
          box(
            title = "The Transformation of Women's Bodies into Administrative Categories", 
            status = "info", solidHeader = TRUE, width = 12,
            div(style = "background: #ecf0f1; padding: 20px; margin-bottom: 20px; border-left: 5px solid #3498db;",
              p(style = "font-size: 1.15em; margin: 0; line-height: 1.6;",
                strong("Critical Reading Guide:"), " These numbers are not neutral epidemiological facts. ",
                "Each statistic represents an act of state coercion—registration was compulsory, exams were enforced, ",
                "punishments were systematically applied. The 'disease cases' were produced by compulsory examinations, ",
                "not voluntary medical seeking. The ratio of women to troops reveals the military-medical nexus: ",
                "women's bodies were regulated to protect imperial military strength."
              )
            ),
            htmlOutput("med_summary_html"),
            br(),
            div(style = "background: #fff3cd; padding: 15px; border-left: 5px solid #ffc107;",
              p(style = "margin: 0; font-size: 0.95em;",
                strong("Historiographic Note:"), " Compare totals across regions and years in context of legislative moments ",
                "(CD Act 1864, 1868, 1880) and military movements. High numbers may reflect administrative intensification ",
                "rather than changes 'on the ground.' Deaths in system are likely undercounted due to discharge practices."
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
              column(12,
                selectInput("export_table", "Select Table to Export:",
                  choices = c("documents", "stations", "station_reports", 
                             "women_admission", "troops", "hospital_operations")
                ),
                selectInput("export_format", "Export Format:",
                  choices = c("CSV", "Excel", "JSON")
                ),
                actionButton("export_data", "Export Data", class = "btn-success")
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
  message('SHINY_SESSION_START token=', session$token, ' pid=', Sys.getpid())
  session$onSessionEnded(function() {
    message('SHINY_SESSION_END token=', session$token)
  })
  # Respect SAFE_MODE toggle to avoid heavy analytics crashing the UI
  safe_mode <- exists('SAFE_MODE') && isTRUE(SAFE_MODE)
  if (safe_mode) {
    message('SAFE_MODE: heavy analytics disabled; map and tables should load')
    # Provide lightweight placeholders / short-circuit heavy reactives
    correlation_data <- reactive({ data.frame() })
    # Disabled heavy plotly outputs
    output$correlation_dual_axis <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$correlation_scatter <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$correlation_metrics_table <- DT::renderDataTable({ DT::datatable(data.frame(Message = 'Disabled in safe mode')) })
    output$med_surveillance_sankey <- renderSankeyNetwork({ NULL })
    output$med_temporal_women_added <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_temporal_avg_registered <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_geo_women_added_by_region <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_geo_avg_registered_by_region <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_surveillance_sankey <- renderSankeyNetwork({ NULL })
    output$med_acts_total <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_acts_timeline <- renderPlotly({ plot_ly() %>% layout(title = 'Disabled (safe mode)') })
    output$med_acts_by_station <- DT::renderDataTable({ DT::datatable(data.frame(Message = 'Disabled in safe mode')) })
  }
  
  # Database connection: open a single connection at session start and reuse it
  con_obj <- connect_to_db()
  conn <- reactive({
    con_obj
  })
  
  # ===== INTERACTIVE MAP FUNCTIONALITY =====
  # Reactive data for map - joins stations, women admissions, and acts
  map_data <- reactive({
    # Handle both single year and year range
    year_range <- input$year_slider
    if (length(year_range) == 2) {
      year_min <- year_range[1]
      year_max <- year_range[2]
    } else {
      year_min <- year_max <- year_range[1]
    }
    
    if (year_min == year_max) {
      message(sprintf("Fetching map data for year: %d", year_min))
    } else {
      message(sprintf("Fetching map data for years: %d-%d", year_min, year_max))
    }
    
    con <- conn()
    if (!DBI::dbIsValid(con)) {
      message("Database connection is not valid")
      return(data.frame())
    }
    
    # Get stations with coordinates
    stations <- tryCatch({
      dbGetQuery(con, "SELECT * FROM stations WHERE latitude IS NOT NULL AND longitude IS NOT NULL")
    }, error = function(e) {
      message("Error querying stations: ", e$message)
      return(data.frame())
    })
    
    message(sprintf("Found %d stations with coordinates", nrow(stations)))
    
    if (nrow(stations) == 0) {
      return(data.frame())
    }
    
    # Get women admission data for selected year(s)
    women_data <- tryCatch({
      dbGetQuery(con, sprintf("
        SELECT station, 
               SUM(women_start_register) as total_registered, 
               SUM(women_added) as total_added,
               SUM(women_removed) as total_removed
        FROM women_admission 
        WHERE year BETWEEN %d AND %d
        GROUP BY station", year_min, year_max))
    }, error = function(e) {
      message("Error querying women_admission: ", e$message)
      return(data.frame())
    })
    
    message(sprintf("Found %d stations with women data for year(s) %d-%d", nrow(women_data), year_min, year_max))
    
    # Get hospital operations data for acts (use most recent act in range)
    hospital_data <- tryCatch({
      dbGetQuery(con, sprintf("
        SELECT station, act
        FROM hospital_operations
        WHERE year BETWEEN %d AND %d
        GROUP BY station
        HAVING year = MAX(year)", year_min, year_max))
    }, error = function(e) {
      message("Error querying hospital_operations: ", e$message)
      return(data.frame())
    })
    
    message(sprintf("Found %d hospital operations records for year(s) %d-%d", nrow(hospital_data), year_min, year_max))
    
    # Join data
    map_df <- stations %>%
      dplyr::left_join(women_data, by = c("name" = "station")) %>%
      dplyr::left_join(hospital_data, by = c("name" = "station")) %>%
      dplyr::mutate(
        total_registered = ifelse(is.na(total_registered), 0, total_registered),
        total_added = ifelse(is.na(total_added), 0, total_added),
        total_removed = ifelse(is.na(total_removed), 0, total_removed),
        # Flag stations with no data
        has_data = total_added > 0 | total_registered > 0 | total_removed > 0,
        # Scale circles: small grey circles for no data, sized circles for data
        radius = ifelse(has_data, pmax(5, sqrt(pmax(0, total_added)) * 3), 4)
      )
    
    # Filter by selected acts if checkbox filters are active
    # Keep stations with no act data (show as grey) but filter the ones with acts
    if (!is.null(input$acts) && length(input$acts) > 0) {
      map_df <- map_df %>% dplyr::filter(is.na(act) | act %in% input$acts)
      message(sprintf("After act filter: %d stations remain", nrow(map_df)))
    }
    
    message(sprintf("Returning %d stations for map display", nrow(map_df)))
    map_df
  })
  
  # Load railway shapefiles (once at startup)
  railway_lines <- tryCatch({
    st_read("data_raw/railway_lines.shp", quiet = TRUE)
  }, error = function(e) {
    message("Railway lines shapefile not found: ", e$message)
    NULL
  })
  
  railway_stations <- tryCatch({
    st_read("data_raw/railway_stations_extended.shp", quiet = TRUE)
  }, error = function(e) {
    message("Railway stations shapefile not found: ", e$message)
    NULL
  })
  
  # Load British India boundary (modern India, Pakistan, Bangladesh, Myanmar borders as proxy)
  india_boundary <- tryCatch({
    # Get country boundaries for the Indian subcontinent
    india <- ne_countries(scale = "medium", country = c("India", "Pakistan", "Bangladesh", "Myanmar"), returnclass = "sf")
    # Ensure CRS is EPSG:4326 (WGS84)
    st_transform(india, crs = 4326)
  }, error = function(e) {
    message("Could not load boundary data: ", e$message)
    NULL
  })
  
  # Initialize the base map
  output$map <- renderLeaflet({
    message("Initializing base map")
    map <- leaflet() %>%
      addTiles() %>%
      setView(lng = 78.9629, lat = 20.5937, zoom = 5)
    
    # Add British India boundary if available
    if (!is.null(india_boundary)) {
      map <- map %>%
        addPolygons(
          data = india_boundary,
          fillColor = "transparent",
          fillOpacity = 0,
          color = "#8B4513",  # Saddle brown
          weight = 3,
          opacity = 0.8,
          dashArray = "5, 5",  # Dashed line
          group = "boundary",
          popup = ~name
        )
    }
    
    map
  })
  
  # Update railway overlays when checkbox changes or year changes
  observe({
    req(input$show_railways, input$year_slider)
    
    if (input$show_railways && !is.null(railway_lines) && !is.null(railway_stations)) {
      # Get the year range
      year_range <- input$year_slider
      max_year <- ifelse(length(year_range) == 2, year_range[2], year_range[1])
      
      # Filter railway lines to only show those opened by the selected year
      railways_filtered <- railway_lines[railway_lines$Year <= max_year, ]
      
      message(sprintf("Adding %d railway lines (opened by year %d) to map", nrow(railways_filtered), max_year))
      
      leafletProxy("map") %>%
        clearGroup("railways") %>%
        clearGroup("railway_stations")
      
      # Only add railways if there are any to display
      if (nrow(railways_filtered) > 0) {
        leafletProxy("map") %>%
          # Add railway lines (only those operational by selected year)
          addPolylines(
            data = railways_filtered,
            color = "#000000",
            weight = 4,
            opacity = 0.9,
            group = "railways",
            popup = ~paste0(
              "<b>", Section, "</b><br>",
              "Railway: ", Railway, "<br>",
              "Opened: ", Month, "/", Day, "/", Year, "<br>",
              "Distance: ", Miles, " miles<br>",
              start_name, " → ", end_name
            ),
            label = ~Section
          ) %>%
          # Add railway station markers
          addCircleMarkers(
            data = railway_stations,
            radius = 5,
            color = "#000000",
            fillColor = "#ffeb3b",
            fillOpacity = 0.9,
            weight = 2,
            group = "railway_stations",
            popup = ~paste0(
              "<b>Railway Station</b><br>",
              "Historic: ", orig_name, "<br>",
              "Modern: ", modern_nam
            ),
            label = ~orig_name
          )
      }
    } else {
      message("Removing railway layers from map")
      leafletProxy("map") %>%
        clearGroup("railways") %>%
        clearGroup("railway_stations")
    }
  })
  
  # Update map markers when data or filters change
  observe({
    req(input$year_slider)
    data <- map_data()
    
    if (nrow(data) == 0) {
      message("No map data to display")
      leafletProxy("map") %>%
        clearMarkers() %>%
        clearControls()
      return()
    }
    
    message(sprintf("Updating map with %d markers", nrow(data)))
    
    # Assign colors based on act type and data availability
    data <- data %>%
      dplyr::mutate(
        marker_color = dplyr::case_when(
          !has_data ~ "#95a5a6",                          # Grey for no women data
          is.na(act) ~ "#34495e",                         # Dark grey for data but no act
          act == "Act XXII of 1864" ~ "#e74c3c",          # Red
          act == "Act XII of 1864" ~ "#c0392b",           # Dark red
          act == "Act XIV of 1868" ~ "#3498db",           # Blue
          act == "Act III of 1880" ~ "#9b59b6",           # Purple
          act == "Voluntary System" ~ "#27ae60",          # Green
          TRUE ~ "#95a5a6"                                # Default grey
        ),
        # Adjust opacity: lower for stations with no data
        marker_opacity = ifelse(has_data, 0.8, 0.5)
      )
    
    leafletProxy("map", data = data) %>%
      clearGroup("lock_hospitals") %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = ~radius,
        group = "lock_hospitals",
        popup = ~paste0(
          "<b>", name, "</b><br>",
          "Region: ", region, "<br>",
          ifelse(has_data, 
            paste0(
              "<b>Women Added to Register: ", total_added, "</b><br>",
              "Total Registered: ", total_registered, "<br>",
              "Removed: ", total_removed, "<br>"
            ),
            "<i style='color:#7f8c8d;'>No women admission data for this year</i><br>"
          ),
          "Act: ", ifelse(is.na(act), "None", act)
        ),
        fillColor = ~marker_color,
        fillOpacity = ~marker_opacity,
        color = "#ffffff",
        weight = 1,
        stroke = TRUE
      )
  })
  
  # Map legend
  output$map_legend <- renderUI({
    railway_legend <- if (!is.null(input$show_railways) && input$show_railways) {
      '
      <hr style="margin: 10px 0;">
      <h4 style="margin-top: 10px; font-size: 13px;">Railway Infrastructure</h4>
      <div style="margin-top: 5px; font-size: 11px; line-height: 1.8;">
        <div style="border-bottom: 2px solid #2c3e50; width: 20px; display: inline-block; margin-right: 5px;"></div> Railway Lines (1853-1890)<br>
        <i class="fa fa-circle" style="color: #34495e; font-size: 8px;"></i> Railway Stations
      </div>'
    } else {
      ""
    }
    
    HTML(paste0('
      <div style="background: white; padding: 10px; border-radius: 4px;">
        <h4 style="margin-top: 0; font-size: 13px;">Circle Size</h4>
        <p style="font-size: 11px; margin: 5px 0;">Indicates <b>women added</b> to Lock Hospital registers</p>
        <hr style="margin: 10px 0;">
        <h4 style="margin-top: 10px; font-size: 13px;">Contagious Diseases Acts</h4>
        <div style="margin-top: 5px; font-size: 11px; line-height: 1.8;">
          <i class="fa fa-circle" style="color: #e74c3c;"></i> Act XXII of 1864<br>
          <i class="fa fa-circle" style="color: #c0392b;"></i> Act XII of 1864<br>
          <i class="fa fa-circle" style="color: #3498db;"></i> Act XIV of 1868<br>
          <i class="fa fa-circle" style="color: #9b59b6;"></i> Act III of 1880<br>
          <i class="fa fa-circle" style="color: #27ae60;"></i> Voluntary System<br>
          <i class="fa fa-circle" style="color: #34495e;"></i> Has Data, No Act<br>
          <i class="fa fa-circle" style="color: #95a5a6; opacity: 0.5;"></i> No Data Available
        </div>
        ', railway_legend, '
      </div>
    '))
  })
  
  # Women admissions timeline
  output$women_timeline <- renderPlotly({
    con <- conn()
    
    yearly_data <- tryCatch({
      dbGetQuery(con, "
        SELECT year, 
               SUM(women_start_register) as total_registered,
               SUM(women_added) as new_admissions,
               SUM(women_removed) as removed
        FROM women_admission 
        GROUP BY year
        ORDER BY year
      ")
    }, error = function(e) {
      message("Error fetching timeline data: ", e$message)
      return(data.frame())
    })
    
    if (nrow(yearly_data) == 0) {
      plot_ly() %>%
        layout(title = "No women admission data available")
    } else {
      plot_ly(yearly_data) %>%
        add_trace(
          x = ~year,
          y = ~total_registered,
          name = "Total Registered",
          type = "scatter",
          mode = "lines+markers",
          line = list(color = "#e74c3c"),
          marker = list(size = 8)
        ) %>%
        add_trace(
          x = ~year,
          y = ~new_admissions,
          name = "New Admissions",
          type = "scatter",
          mode = "lines+markers",
          line = list(color = "#3498db"),
          marker = list(size = 8)
        ) %>%
        layout(
          title = "Women Admissions Over Time",
          xaxis = list(title = "Year"),
          yaxis = list(title = "Number of Women"),
          hovermode = "x unified",
          legend = list(x = 0.1, y = 0.9)
        )
    }
  })
  # ===== END INTERACTIVE MAP FUNCTIONALITY =====
  
  # Image Gallery Navigation
  current_image_index <- reactiveVal(1)
  
  observeEvent(input$next_image, {
    img_dir <- "content/images"
    img_files <- list.files(img_dir, pattern = "\\.(jpg|jpeg|png|gif|webp)$", ignore.case = TRUE)
    current <- current_image_index()
    if (current < length(img_files)) {
      current_image_index(current + 1)
    }
  })
  
  observeEvent(input$prev_image, {
    current <- current_image_index()
    if (current > 1) {
      current_image_index(current - 1)
    }
  })
  
  # Make the current index available to the UI
  observe({
    updateQueryString(sprintf("?image=%d", current_image_index()))
  })
  
  # Close connection when app stops
  onStop(function() {
    try({ DBI::dbDisconnect(con_obj) }, silent = TRUE)
  })
  
  # Overview Tab - Value Boxes
  output$story_total_stats <- renderUI({
    n_docs <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM documents")$count
    n_stations <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM stations")$count
    n_women <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM women_admission")$count
    n_troops <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM troops")$count

    # Calculate year ranges and missing years for all datasets
    women <- women_df()
    troops <- troops_df()
    ops <- hospital_ops_enriched()

    # Helper: get missing years in contiguous range
    get_missing_years <- function(years) {
      years <- sort(unique(na.omit(years)))
      if (length(years) < 2) return(character(0))
      yr_min <- min(years)
      yr_max <- max(years)
      expected <- seq(yr_min, yr_max)
      missing <- setdiff(expected, years)
      if (length(missing) > 0) return(as.character(missing))
      character(0)
    }

    # Overall combined years across all datasets
    all_years <- c(
      if (nrow(women) > 0 && "year" %in% names(women)) women$year else numeric(0),
      if (nrow(troops) > 0 && "year" %in% names(troops)) troops$year else numeric(0),
      if (nrow(ops) > 0 && "year" %in% names(ops)) ops$year else numeric(0)
    )
    overall_missing <- get_missing_years(all_years)

    # Per-region combined years across datasets
    regions <- sort(unique(na.omit(c(
      if (nrow(women) > 0 && "region" %in% names(women)) women$region else character(0),
      if (nrow(troops) > 0 && "region" %in% names(troops)) troops$region else character(0),
      if (nrow(ops) > 0 && "region" %in% names(ops)) ops$region else character(0)
    ))))

    region_missing_parts <- c()
    if (length(regions) > 0) {
      for (r in regions) {
        years_r <- c(
          if (nrow(women) > 0 && all(c("region","year") %in% names(women))) women$year[women$region == r] else numeric(0),
          if (nrow(troops) > 0 && all(c("region","year") %in% names(troops))) troops$year[troops$region == r] else numeric(0),
          if (nrow(ops) > 0 && all(c("region","year") %in% names(ops))) ops$year[ops$region == r] else numeric(0)
        )
        miss_r <- get_missing_years(years_r)
        if (length(miss_r) > 0) {
          region_missing_parts <- c(region_missing_parts, paste0(r, ": ", paste(miss_r, collapse = ", ")))
        }
      }
    }

    # Build concise missing years line(s)
    missing_line <- ""
    if (length(overall_missing) > 0 || length(region_missing_parts) > 0) {
      overall_text <- if (length(overall_missing) > 0) paste0("We were not able to gather info for these years (overall): ", paste(overall_missing, collapse = ", ")) else NULL
      region_text <- if (length(region_missing_parts) > 0) paste0("By region: ", paste(region_missing_parts, collapse = " | ")) else NULL
      line_text <- paste(na.omit(c(overall_text, region_text)), collapse = ". ")
      missing_line <- paste0("<div style='margin-top:10px; color:#7f8c8d; font-size:0.95em;'>", line_text, ".</div>")
    }

    HTML(paste0(
      "<div>",
      "<div class='row' style='margin-bottom:0;'>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#3498db;'>", n_stations, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Stations</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#e74c3c;'>", n_women, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Women Records</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#f39c12;'>", n_troops, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Troop Records</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#9b59b6;'>", n_docs, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Source Documents</div>",
      "  </div>",
      "</div>",
      missing_line,
      "</div>"
    ))
  })
  
  # Quality Summary Table
  output$quality_summary <- DT::renderDataTable({
    tables <- c("women_admission", "troops", "hospital_operations", "stations")
    total_records <- sapply(tables, function(t) {
      dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t))$count
    })
    complete_records <- sapply(tables, function(t) {
      if (t %in% c("women_admission", "troops")) {
        dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL AND source_name IS NOT NULL"))$count
      } else if (t == "hospital_operations") {
        dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", t, "WHERE doc_id IS NOT NULL"))$count
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
  
  # Data Tables Tab - reactive trigger for refreshing table
  table_refresh <- reactiveVal(0)
  
  output$data_table <- DT::renderDataTable({
    # Add dependency on refresh trigger
    table_refresh()
    # Try to fetch rowid; some tables or views may not expose rowid, so fallback
    query_rowid <- paste("SELECT rowid, * FROM", input$table_select)
    data <- tryCatch({
      d <- dbGetQuery(conn(), query_rowid)
      # Mark that rowid was available
      attr(d, 'rowid_available') <- TRUE
      d
    }, error = function(e) {
      # Fallback: select all columns, create a synthetic rownum and mark table non-editable
      dat <- tryCatch(dbGetQuery(conn(), paste("SELECT * FROM", input$table_select)), error = function(e2) {
        # If even this fails, return empty data.frame
        return(data.frame())
      })
      if (nrow(dat) > 0) dat$.__rownum__ <- seq_len(nrow(dat))
      attr(dat, 'rowid_available') <- FALSE
      dat
    })
    rowid_available <- isTRUE(attr(data, 'rowid_available'))

    # Log debug info for table rendering
    try({
      message(sprintf('data_table render: table=%s rows=%d rowid_available=%s', input$table_select, nrow(data), as.character(rowid_available)))
    }, silent = TRUE)

    if (!rowid_available) {
      # Non-editable fallback table
      DT::datatable(data, 
        editable = FALSE,
        selection = 'single',
        options = list(pageLength = 25, scrollX = TRUE, dom = 'Bfrtip', buttons = c('copy','csv','excel','print')), 
        extensions = 'Buttons',
        rownames = FALSE
      )
    } else {
      DT::datatable(data, 
        editable = list(target = 'cell', disable = list(columns = 0)),  # Make cells editable except rowid
        selection = 'single',  # Enable row selection for delete
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ), 
        extensions = 'Buttons',
        rownames = FALSE
      )
    }
  })
  
  # Handle cell edits in data_table
  observeEvent(input$data_table_cell_edit, {
    info <- input$data_table_cell_edit
    req(info, input$table_select)
    
    # Get current data (try rowid, otherwise abort with notification)
    data <- tryCatch(dbGetQuery(conn(), paste("SELECT rowid, * FROM", input$table_select)), error = function(e) {
      showNotification("This table is not editable (rowid not available).", type = 'warning', duration = 5)
      return(NULL)
    })
    req(is.data.frame(data))
    
    # Extract edit info
    row_num <- info$row
    col_num <- info$col + 1  # R is 1-indexed, JS is 0-indexed
    new_value <- info$value
    
    # Get rowid and column name
    rowid <- data[row_num, "rowid"]
    col_name <- names(data)[col_num]
    
    # Skip if trying to edit rowid
    if (col_name == "rowid") return()
    
    # Build UPDATE query
    update_query <- sprintf(
      "UPDATE %s SET %s = ? WHERE rowid = ?",
      input$table_select,
      col_name
    )
    
    # Execute update
    tryCatch({
      dbExecute(conn(), update_query, params = list(new_value, rowid))
      showNotification(
        paste("Updated", col_name, "in row", row_num),
        type = "message",
        duration = 3
      )
    }, error = function(e) {
      showNotification(
        paste("Error updating:", e$message),
        type = "error",
        duration = 5
      )
    })
  })
  
  # Delete selected row
  observeEvent(input$delete_row_btn, {
    # Only respond to a real user click (actionButton increments from 0)
    req(isTRUE(!is.null(input$delete_row_btn)) && input$delete_row_btn > 0)
    req(input$data_table_rows_selected, input$table_select)
    
    # Get current data
    query <- paste("SELECT rowid, * FROM", input$table_select)
    data <- dbGetQuery(conn(), query)
    
    # Get selected row
    row_num <- input$data_table_rows_selected
    rowid <- data[row_num, "rowid"]
    
    # Confirm and delete
    showModal(modalDialog(
      title = "Confirm Deletion",
      paste("Are you sure you want to delete row", row_num, "from", input$table_select, "?"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete", "Delete", class = "btn-danger")
      )
    ))
  })
  
  observeEvent(input$confirm_delete, {
    # guard to ensure this was triggered by a user
    req(isTRUE(!is.null(input$confirm_delete)) && input$confirm_delete > 0)
    req(input$data_table_rows_selected, input$table_select)
    
    # Get current data
    query <- paste("SELECT rowid, * FROM", input$table_select)
    data <- dbGetQuery(conn(), query)
    
    # Get selected row
    row_num <- input$data_table_rows_selected
    rowid <- data[row_num, "rowid"]
    
    # Delete
    tryCatch({
      dbExecute(conn(), paste("DELETE FROM", input$table_select, "WHERE rowid = ?"), params = list(rowid))
      showNotification(
        paste("Deleted row", row_num, "from", input$table_select),
        type = "warning",
        duration = 3
      )
      removeModal()
      # Trigger table refresh
      table_refresh(table_refresh() + 1)
    }, error = function(e) {
      showNotification(
        paste("Error deleting:", e$message),
        type = "error",
        duration = 5
      )
      removeModal()
    })
  })
  
  # Add new row
  observeEvent(input$add_row_btn, {
    # Only respond to user click
    req(isTRUE(!is.null(input$add_row_btn)) && input$add_row_btn > 0)
    req(input$table_select)
    
    # Get table structure
    cols_query <- paste0("PRAGMA table_info(", input$table_select, ")")
    cols_info <- dbGetQuery(conn(), cols_query)
    
    # Create input fields for each column (except rowid and auto-increment primary keys)
    input_fields <- lapply(seq_len(nrow(cols_info)), function(i) {
      col <- cols_info[i, ]
      if (col$name == "rowid" || (col$pk == 1 && grepl("INTEGER", col$type, ignore.case = TRUE))) {
        return(NULL)  # Skip auto-increment primary keys
      }
      textInput(paste0("new_", col$name), label = paste(col$name, ":"), value = "")
    })
    input_fields <- Filter(Negate(is.null), input_fields)
    
    showModal(modalDialog(
      title = paste("Add New Row to", input$table_select),
      do.call(tagList, input_fields),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_add", "Add Row", class = "btn-success")
      ),
      size = "l"
    ))
  })
  
  observeEvent(input$confirm_add, {
    # Ensure this was triggered by user confirm button
    req(isTRUE(!is.null(input$confirm_add)) && input$confirm_add > 0)
    req(input$table_select)
    
    # Get table structure
    cols_query <- paste0("PRAGMA table_info(", input$table_select, ")")
    cols_info <- dbGetQuery(conn(), cols_query)
    
    # Collect values from inputs
    cols_to_insert <- cols_info %>%
      filter(name != "rowid", !(pk == 1 & grepl("INTEGER", type, ignore.case = TRUE)))
    
    col_names <- cols_to_insert$name
    values <- sapply(col_names, function(nm) {
      val <- input[[paste0("new_", nm)]]
      if (is.null(val) || val == "") NA else val
    })
    
    # Build INSERT query
    placeholders <- paste(rep("?", length(col_names)), collapse = ", ")
    insert_query <- sprintf(
      "INSERT INTO %s (%s) VALUES (%s)",
      input$table_select,
      paste(col_names, collapse = ", "),
      placeholders
    )
    
    # Execute insert
    tryCatch({
      dbExecute(conn(), insert_query, params = as.list(values))
      showNotification(
        paste("Added new row to", input$table_select),
        type = "message",
        duration = 3
      )
      removeModal()
      # Trigger table refresh
      table_refresh(table_refresh() + 1)
    }, error = function(e) {
      showNotification(
        paste("Error adding row:", e$message),
        type = "error",
        duration = 5
      )
    })
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
    } else if (table_name %in% c("women_admission", "troops")) {
      null_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id IS NULL OR source_name IS NULL"))
      validation_results <- paste(validation_results, "Records with NULL doc_id or source_name:", null_check$count, "\n")
    } else if (table_name == "hospital_operations") {
      null_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id IS NULL"))
      validation_results <- paste(validation_results, "Records with NULL doc_id:", null_check$count, "\n")
    }
    
    # Check for empty strings
    if (table_name %in% c("documents", "women_admission", "troops")) {
      empty_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id = '' OR source_name = ''"))
      validation_results <- paste(validation_results, "Records with empty strings:", empty_check$count, "\n")
    } else if (table_name == "hospital_operations") {
      empty_check <- dbGetQuery(conn(), paste("SELECT COUNT(*) as count FROM", table_name, "WHERE doc_id = ''"))
      validation_results <- paste(validation_results, "Records with empty doc_id:", empty_check$count, "\n")
    }
    
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

  # Network: information recorded about Men (Troops)
  output$med_men_network <- renderForceNetwork({
    # Get data and filter by timeline
    year_range <- input$pipeline_years
    if (is.null(year_range)) year_range <- c(1860, 1890)
    df <- tryCatch(troops_df(), error = function(e) data.frame())
    if (!is.data.frame(df) || nrow(df) == 0) {
      return(forceNetwork(Links = data.frame(source=integer(), target=integer(), value=numeric()),
                          Nodes = data.frame(name=character(), group=character()),
                          Source = "source", Target = "target", NodeID = "name", Group = "group"))
    }
    df <- df %>% dplyr::filter(year >= year_range[1], year <= year_range[2])
    validate(need(nrow(df) > 0, "No troop records in selected years"))

    # Helper to compute non-empty coverage
    non_empty <- function(x) {
      if (is.numeric(x)) { !is.na(x) } else { !is.na(x) & nzchar(as.character(x)) }
    }

    # Variable categories mapping
    var_map <- list(
      list(cat = "Strength", cols = c("avg_strength")),
      list(cat = "Admissions", cols = c("total_admissions")),
      list(cat = "Disease", cols = c("primary_syphilis","secondary_syphilis","gonorrhoea","orchitis_gonorrhoea","phimosis","warts")),
      list(cat = "Contraction", cols = c("contracted_at_station","contracted_elsewhere")),
      list(cat = "Ratios", cols = c("ratio_per_1000")),
      list(cat = "Regiments", cols = c("Regiments")),
      list(cat = "Occupation", cols = c("period_of_occupation"))
    )

    pretty_label <- function(x) {
      x <- gsub("_", " ", x)
      x <- gsub("ratio per 1000", "Ratio per 1000", x, ignore.case = TRUE)
      tools::toTitleCase(x)
    }

    # Build nodes and links
  nodes <- data.frame(name = "Men (Troops)", group = "Entity", stringsAsFactors = FALSE)
  links <- data.frame(source = integer(0), target = integer(0), value = numeric(0), stringsAsFactors = FALSE)

    idx <- 1
    for (grp in var_map) {
      for (col in grp$cols) {
        if (col %in% names(df)) {
          cov <- round(100 * mean(non_empty(df[[col]]), na.rm = TRUE), 1)
          label <- pretty_label(col)
          nodes <- rbind(nodes, data.frame(name = label, group = grp$cat, stringsAsFactors = FALSE))
          links <- rbind(links, data.frame(source = 0, target = idx, value = ifelse(is.finite(cov), max(cov, 0.1), 0.1), stringsAsFactors = FALSE))
          idx <- idx + 1
        }
      }
    }

    colourScale <- JS(
      "d3.scaleOrdinal()\n        .domain(['Entity','Strength','Admissions','Disease','Contraction','Ratios','Regiments','Occupation'])\n        .range(['#34495e','#27ae60','#2980b9','#e74c3c','#f39c12','#8e44ad','#16a085','#7f8c8d'])"
    )

    forceNetwork(
      Links = links, Nodes = nodes,
      Source = "source", Target = "target",
      NodeID = "name", Group = "group",
      Value = "value", opacity = 0.95, zoom = TRUE,
      linkDistance = 120, charge = -380,
      legend = FALSE, fontSize = 12,
      colourScale = colourScale,
      opacityNoHover = 0.2,
      linkColour = "#95a5a6"
    )
  })

  # Network: information recorded about Women
  output$med_women_network <- renderForceNetwork({
    year_range <- input$pipeline_years
    if (is.null(year_range)) year_range <- c(1860, 1890)
    df <- tryCatch(women_df(), error = function(e) data.frame())
    if (!is.data.frame(df) || nrow(df) == 0) {
      return(forceNetwork(Links = data.frame(source=integer(), target=integer(), value=numeric()),
                          Nodes = data.frame(name=character(), group=character()),
                          Source = "source", Target = "target", NodeID = "name", Group = "group"))
    }
    df <- df %>% dplyr::filter(year >= year_range[1], year <= year_range[2])
    validate(need(nrow(df) > 0, "No women records in selected years"))

    non_empty <- function(x) {
      if (is.numeric(x)) { !is.na(x) } else { !is.na(x) & nzchar(as.character(x)) }
    }

    var_map <- list(
      list(cat = "Register", cols = c("women_start_register","women_added","women_removed","women_end_register","avg_registered")),
      list(cat = "Compliance/Discipline", cols = c("non_attendance_cases","fined_count","imprisonment_count")),
      list(cat = "Disease", cols = c("disease_primary_syphilis","disease_secondary_syphilis","disease_gonorrhoea","disease_leucorrhoea")),
      list(cat = "Outcomes", cols = c("discharges","deaths","Total")),
      list(cat = "Notes", cols = c("side_notes"))
    )

    pretty_label <- function(x) tools::toTitleCase(gsub("_", " ", x))

  nodes <- data.frame(name = "Women", group = "Entity", stringsAsFactors = FALSE)
  links <- data.frame(source = integer(0), target = integer(0), value = numeric(0), stringsAsFactors = FALSE)
    idx <- 1
    for (grp in var_map) {
      for (col in grp$cols) {
        if (col %in% names(df)) {
          cov <- round(100 * mean(non_empty(df[[col]]), na.rm = TRUE), 1)
          label <- pretty_label(col)
          nodes <- rbind(nodes, data.frame(name = label, group = grp$cat, stringsAsFactors = FALSE))
          links <- rbind(links, data.frame(source = 0, target = idx, value = ifelse(is.finite(cov), max(cov, 0.1), 0.1), stringsAsFactors = FALSE))
          idx <- idx + 1
        }
      }
    }

    colourScale <- JS(
      "d3.scaleOrdinal()\n        .domain(['Entity','Register','Compliance/Discipline','Disease','Outcomes','Notes'])\n        .range(['#34495e','#27ae60','#f39c12','#e74c3c','#2980b9','#8e44ad'])"
    )

    forceNetwork(
      Links = links, Nodes = nodes,
      Source = "source", Target = "target",
      NodeID = "name", Group = "group",
      Value = "value", opacity = 0.95, zoom = TRUE,
      linkDistance = 120, charge = -380,
      legend = FALSE, fontSize = 12,
      colourScale = colourScale,
      opacityNoHover = 0.2,
      linkColour = "#95a5a6"
    )
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
    dbGetQuery(conn(), "SELECT * FROM hospital_notes")
  })
  troops_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM troops")
  })
  stations_df <- reactive({
    dbGetQuery(conn(), "SELECT * FROM stations")
  })

  # ---------------------
  # DS_Dataset ingestion (optional) and staff roles extraction
  # ---------------------
  .find_ds_dataset_file <- function() {
    candidates <- c(
      "DS_Dataset.xlsx",
      "content/DS_Dataset.xlsx",
      "data_raw/DS_Dataset.xlsx",
      "archive/DS_Dataset.xlsx",
      "archive/data_raw/DS_Dataset.xlsx"
    )
    existing <- candidates[file.exists(candidates)]
    if (length(existing) > 0) existing[[1]] else NULL
  }

  .normalize_station_key <- function(x) {
    tolower(trimws(as.character(x)))
  }

  # Version bump to re-trigger DS ingestion after upload
  ds_version <- reactiveVal(0)

  ds_dataset_clean <- reactive({
    v <- ds_version()  # dependency
    path <- .find_ds_dataset_file()
    if (is.null(path)) return(data.frame())
    if (!requireNamespace("readxl", quietly = TRUE)) {
      message("DS_Dataset found at ", path, " but readxl is not installed; skipping ingestion.")
      return(data.frame())
    }
    # Read all sheets defensively
    sheets <- tryCatch(readxl::excel_sheets(path), error = function(e) character(0))
    if (length(sheets) == 0) return(data.frame())
    lst <- lapply(sheets, function(sh) {
      df <- tryCatch(suppressWarnings(readxl::read_excel(path, sheet = sh)), error = function(e) NULL)
      if (is.null(df) || nrow(df) == 0) return(NULL)
      df$.__sheet__ <- sh
      df
    })
    lst <- Filter(Negate(is.null), lst)
    if (length(lst) == 0) return(data.frame())
    df <- dplyr::bind_rows(lst)
    if (nrow(df) == 0) return(df)
    # Heuristic column harmonization
    names(df) <- tolower(gsub("[^a-z0-9]+", "_", names(df)))
    # Station
    station_col <- intersect(c("station","name","cantonment","station_name"), names(df))
    if (length(station_col) == 0) df$station <- NA_character_ else df$station <- df[[station_col[1]]]
    # Year
    if ("year" %in% names(df)) {
      year_raw <- df$year
    } else if ("date" %in% names(df)) {
      year_raw <- df$date
    } else {
      year_raw <- NA
    }
    df$year <- suppressWarnings(as.integer(stringr::str_extract(as.character(year_raw), "[0-9]{4}")))
    # Region/Country if present; otherwise try to enrich from stations
    if (!("region" %in% names(df))) df$region <- NA_character_
    if (!("country" %in% names(df))) df$country <- NA_character_
    # Join with stations to backfill region/country
    st <- stations_df()
    if (nrow(st) > 0) {
      st <- st %>% dplyr::mutate(station_key = .normalize_station_key(dplyr::coalesce(.data$name, .data$station))) %>%
        dplyr::select(station_key, region_st = .data$region, country_st = .data$country)
      df <- df %>%
        dplyr::mutate(station_key = .normalize_station_key(.data$station)) %>%
        dplyr::left_join(st, by = "station_key") %>%
        dplyr::mutate(
          region = dplyr::coalesce(.data$region, .data$region_st),
          country = dplyr::coalesce(.data$country, .data$country_st)
        ) %>%
        dplyr::select(-dplyr::any_of(c("region_st","country_st","station_key")))
    }
    # Build a text blob across all character columns (excluding obvious id fields)
    char_cols <- names(df)[vapply(df, is.character, logical(1))]
    exclude <- c("station","region","country","__sheet__")
    text_cols <- setdiff(char_cols, exclude)
    if (length(text_cols) == 0) {
      df$text_blob <- NA_character_
    } else {
      df$text_blob <- apply(df[text_cols], 1, function(row) {
        x <- paste(row, collapse = " ")
        x <- .clean_remarks(.strip_specials(x))
        tolower(ifelse(is.na(x), "", x))
      })
    }
    # Role dictionaries (expandable)
    male_roles <- c("surgeon","apothecary","doctor","medical officer","m\\.?o\\.?","secretary","dresser","compounder")
    female_roles <- c("matron","nurse","midwife","ayah")
    # Build regex
    male_rx <- paste0("\\b(", paste(male_roles, collapse = "|"), ")s?\\b")
    female_rx <- paste0("\\b(", paste(female_roles, collapse = "|"), ")s?\\b")
    neg_rx <- "\\b(no|without|vacant|lacking|not appointed)\\b.{0,20}"
    # Count mentions and negate obvious negations
    df$male_mentions_pos <- ifelse(is.na(df$text_blob), 0L, stringr::str_count(df$text_blob, regex(male_rx, ignore_case = TRUE)))
    df$female_mentions_pos <- ifelse(is.na(df$text_blob), 0L, stringr::str_count(df$text_blob, regex(female_rx, ignore_case = TRUE)))
    df$male_mentions_neg <- ifelse(is.na(df$text_blob), 0L, stringr::str_count(df$text_blob, regex(paste0(neg_rx, male_rx), ignore_case = TRUE)))
    df$female_mentions_neg <- ifelse(is.na(df$text_blob), 0L, stringr::str_count(df$text_blob, regex(paste0(neg_rx, female_rx), ignore_case = TRUE)))
    df$male_mentions <- pmax(0L, df$male_mentions_pos - df$male_mentions_neg)
    df$female_mentions <- pmax(0L, df$female_mentions_pos - df$female_mentions_neg)
    df$total_mentions <- df$male_mentions + df$female_mentions
    # Keep key fields for aggregation (retain text_blob for word cloud source)
    df %>% dplyr::select(station, region, country, year, male_mentions, female_mentions, total_mentions, text_blob, `__sheet__`)
  })

  # Prefer DB table if available; fall back to Excel-derived cleaned data
  ds_mentions_source <- reactive({
    con <- conn()
    tbl <- "ds_staff_mentions"
    if (DBI::dbExistsTable(con, tbl)) {
      out <- tryCatch(DBI::dbReadTable(con, tbl), error = function(e) NULL)
      if (!is.null(out) && nrow(out) > 0) return(out)
    }
    ds_dataset_clean()
  })

  # Status readout for DS dataset
  output$ds_dataset_status <- renderText({
    con <- conn(); tbl <- "ds_staff_mentions"; has_tbl <- DBI::dbExistsTable(con, tbl)
    path <- .find_ds_dataset_file(); has_file <- !is.null(path)
    src <- if (has_tbl) "DB table ds_staff_mentions" else if (has_file) basename(path) else "none"
    ds <- ds_mentions_source()
    if (nrow(ds) == 0) {
      return(paste0("DS source: ", src, ". No usable rows. Place DS_Dataset.xlsx in repo or save to DB."))
    }
    yr <- range(na.omit(ds$year)); yr_text <- if (all(is.infinite(yr))) "N/A" else paste(yr, collapse = "-")
    paste0(
      "DS source: ", src,
      " | Rows: ", nrow(ds),
      " | Years: ", yr_text,
      " | Regions: ", length(unique(na.omit(ds$region)))
    )
  })

  # Save cleaned DS dataset to SQLite
  observeEvent(input$ds_save_to_db, {
    ds <- ds_mentions_source()
    validate(need(nrow(ds) > 0, "No DS dataset rows to save"))
    tbl <- "ds_staff_mentions"
    con <- conn()
    ok <- TRUE; msg <- NULL
    try({
      if (DBI::dbExistsTable(con, tbl)) {
        # Replace with latest cleaned extract
        DBI::dbRemoveTable(con, tbl)
      }
      ds_to_save <- ds
      ds_to_save$created_at <- as.character(Sys.time())
      DBI::dbWriteTable(con, tbl, ds_to_save, overwrite = FALSE, append = FALSE)
    }, silent = TRUE)
    if (!DBI::dbExistsTable(con, tbl)) {
      output$ds_save_status <- renderText("Failed to save DS staff mentions to database.")
    } else {
      n <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
      output$ds_save_status <- renderText(paste0("Saved ", n, " rows to table '", tbl, "'."))
    }
  })

  # Handle file upload: save as data_raw/DS_Dataset.xlsx, then re-ingest and auto-save to DB
  observeEvent(input$ds_upload, {
    files <- input$ds_upload
    req(files)
    dest_dir <- "data_raw"; if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    dest <- file.path(dest_dir, "DS_Dataset.xlsx")
    copied <- tryCatch(file.copy(files$datapath[1], dest, overwrite = TRUE), error = function(e) FALSE)
    if (!isTRUE(copied)) {
      output$ds_save_status <- renderText("Upload failed: could not save DS_Dataset.xlsx to data_raw/.")
      return()
    }
    # bump version to re-read
    ds_version(ds_version() + 1)
    # auto-save to DB
    isolate({
      ds <- ds_dataset_clean()
      if (nrow(ds) > 0) {
        tbl <- "ds_staff_mentions"; con <- conn()
        try({ if (DBI::dbExistsTable(con, tbl)) DBI::dbRemoveTable(con, tbl) }, silent = TRUE)
        ds$created_at <- as.character(Sys.time())
        ok <- tryCatch({ DBI::dbWriteTable(con, tbl, ds, overwrite = FALSE, append = FALSE); TRUE }, error = function(e) FALSE)
        if (ok) {
          n <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
          output$ds_save_status <- renderText(paste0("Uploaded and saved ", n, " rows to '", tbl, "'."))
        } else {
          output$ds_save_status <- renderText("Uploaded file saved, but failed to write to DB.")
        }
      } else {
        output$ds_save_status <- renderText("Uploaded file saved, but no usable rows after cleaning.")
      }
    })
  })

  # Simple metrics summary to aid visibility
  output$ds_metrics_text <- renderUI({
    ds <- ds_mentions_source()
    if (nrow(ds) == 0) {
      return(HTML("<div style='color:#7f8c8d'>No staff mentions available yet. Upload DS_Dataset.xlsx or use the Save button if you have already ingested.</div>"))
    }
    tot_m <- sum(ds$male_mentions, na.rm = TRUE)
    tot_f <- sum(ds$female_mentions, na.rm = TRUE)
    yr <- range(na.omit(ds$year)); yr_text <- if (all(is.infinite(yr))) "N/A" else paste(yr, collapse = "-")
    
    # Identify missing years in the range
    years_present <- sort(unique(na.omit(ds$year)))
    missing_years_text <- ""
    if (length(years_present) > 1) {
      yr_min <- min(years_present)
      yr_max <- max(years_present)
      expected_years <- seq(yr_min, yr_max)
      missing_years <- setdiff(expected_years, years_present)
      if (length(missing_years) > 0) {
        missing_years_text <- paste0(
          " &nbsp; | &nbsp; <span style='color:#e74c3c'><b>Missing years</b>: ",
          paste(missing_years, collapse = ", "),
          "</span>"
        )
      }
    }
    
    HTML(paste0(
      "<div style='margin:8px 0; color:#2c3e50'>",
      "<b>Total mentions</b>: ", (tot_m + tot_f),
      " &nbsp; | &nbsp; <span style='color:#2c3e50'><b>Male</b>: ", tot_m, "</span>",
      " &nbsp; | &nbsp; <span style='color:#9b59b6'><b>Female</b>: ", tot_f, "</span>",
      " &nbsp; | &nbsp; <b>Years</b>: ", yr_text,
      missing_years_text,
      "</div>"
    ))
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
  `%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
  }

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
    # Remove specific unwanted patterns like "Ae108:3'"AMadras 1-merged copy.pdf'"AL30-L32""A"e
    # This pattern appears in various forms, so we'll remove all variations
    x0 <- gsub('"*Ae\\d+:\\d+[\'"]+"A[^"]*\\.pdf[\'"]+"AL\\d+-L\\d+[\'"]+"A"e\\.?', '', x0)
    x0 <- gsub('Ae\\d+:\\d+[\'"]+"A[^"]*\\.pdf[\'"]+"AL\\d+-L\\d+[\'"]+"A"e\\.?', '', x0)
    # Remove any remaining variations with double quotes
    x0 <- gsub('"Ae\\d+:\\d+.*?\\.pdf.*?L\\d+"', '', x0)
    # Clean up multiple commas and periods
    x0 <- gsub('[.,]+\\s*[.,]+', '.', x0)
    x0 <- gsub('^[.,\\s]+', '', x0)
    x0 <- gsub('[.,\\s]+$', '', x0)
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

  # Specialized cleaning for remarks: remove PDF artifact strings and boilerplate
  .clean_remarks <- function(x) {
    if (is.null(x)) return(x)
    x0 <- as.character(x)
    # Remove sequences like Ae108:3'"AMadras 1-merged copy.pdf'"AL22-L32""A"e (and variants)
    # Broad pattern: Ae<d>:<d> ... .pdf ... L<d>-L<d> ... A"e with optional quotes in-between
    x0 <- gsub('\"*Ae\\d+:\\d+[^\n]*?\\.pdf[^\n]*?L\\d+-L\\d+[^\n]*?A\"e\\.?', '', x0, perl = TRUE)
    # Run a second pass in case of multiple concatenated artifacts
    x0 <- gsub('\"*Ae\\d+:\\d+[^\n]*?\\.pdf[^\n]*?L\\d+-L\\d+[^\n]*?A\"e\\.?', '', x0, perl = TRUE)
    # Remove boilerplate like "No explicit 1883 detail visible in extract." (any year)
    x0 <- gsub('No explicit [0-9]{4} detail visible in extract\\.?', '', x0, ignore.case = TRUE)
    # Normalize whitespace and punctuation leftovers
    x0 <- gsub('[\t ]+', ' ', x0)
    x0 <- gsub('([,.;:])\1+', '\\1', x0, perl = TRUE)
    x0 <- gsub('^[,.;: ]+|[,.;: ]+$', '', x0)
    x0[x0 == ""] <- NA_character_
    x0
  }

  # Reactive cleaned Hospital Notes dataset
  hospital_notes_df <- reactive({
    # Load ops table
    ops <- ops_df()
    if (nrow(ops) == 0) return(ops)
    cols <- dbGetQuery(conn(), "PRAGMA table_info(hospital_operations)")$name
    want <- c(
      "station","region","country","year",
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
        ops_inspection_regularity = .normalize_regularity(ops_inspection_regularity),
        ops_unlicensed_control_notes = .strip_specials(ops_unlicensed_control_notes),
        ops_committee_activity_notes = .strip_specials(ops_committee_activity_notes),
        remarks = .clean_remarks(.strip_specials(remarks)),
        .key = .data[[key_col]],
        .key_col = key_col
      )
  })

  # ---------------------
  # Story page: curated terms word cloud (Hospital Notes only)
  # ---------------------
  story_terms_counts <- reactive({
    hn <- hospital_notes_df()
    if (nrow(hn) == 0) {
      # Show all curated terms at equal weight if no notes are available
      return(data.frame(term = c(
        "clandestine women","unregistered women","registered women",
        "public/bazaar women","common prostitutes","registered prostitutes",
        "unregistered prostitutes","dancing/nautch girls","diseased women",
        "women examined","women detained","women imprisoned","women fined",
        "native women","european women","servants","ayahs"
      ), freq = 1L, stringsAsFactors = FALSE))
    }
    text <- paste(
      tolower(paste(na.omit(hn$ops_unlicensed_control_notes), collapse = " \n ")),
      tolower(paste(na.omit(hn$ops_committee_activity_notes), collapse = " \n ")),
      tolower(paste(na.omit(hn$remarks), collapse = " \n "))
    )
    txt <- .clean_remarks(.strip_specials(text))
    # Canonical labels -> regex (synonyms included)
    terms <- list(
      "clandestine women" = "\\bclandestine women\\b|\\bclandestine\\b",
      "unregistered women" = "\\bunregistered women\\b",
      "registered women" = "\\bregistered women\\b",
      "public/bazaar women" = "\\bpublic women\\b|\\bwomen of the town\\b|\\bbazaar women\\b",
      "registered prostitutes" = "\\bregistered prostitutes?\\b",
      "unregistered prostitutes" = "\\bunregistered prostitutes?\\b",
      "common prostitutes" = "\\bcommon prostitutes?\\b",
      "dancing/nautch girls" = "\\bdancing girls\\b|\\bnautch girls\\b",
      "diseased women" = "\\bdiseased women\\b",
      "women examined" = "\\bwomen examined\\b",
      "women detained" = "\\bwomen detained\\b",
      "women imprisoned" = "\\bwomen imprisoned\\b",
      "women fined" = "\\bwomen fined\\b",
      "native women" = "\\bnative women\\b",
      "european women" = "\\beuropean women\\b",
      "servants" = "\\bservants?\\b",
      "ayahs" = "\\bayahs?\\b|\\bayah\\b"
    )
    df <- lapply(names(terms), function(lbl) {
      rx <- terms[[lbl]]
      n <- if (is.null(txt) || is.na(txt) || nchar(txt) == 0) 0L else stringr::str_count(txt, regex(rx, ignore_case = TRUE))
      data.frame(term = lbl, freq = as.integer(n), stringsAsFactors = FALSE)
    }) %>% dplyr::bind_rows()
    df$freq[is.na(df$freq)] <- 0L
    # Ensure every curated term is visible at least minimally
    df$freq <- pmax(1L, df$freq)
    df
  })

  output$story_terms_viz <- renderUI({
    if (requireNamespace("wordcloud2", quietly = TRUE)) {
      # Use dynamic function call to avoid loading wordcloud2 namespace at server init
      wc2_output <- get("wordcloud2Output", envir = asNamespace("wordcloud2"))
      wc2_output("story_terms_wordcloud", height = 560)
    } else {
      plotlyOutput("story_terms_bar", height = 560)
    }
  })

  # Wordcloud renderer (when available) - conditionally define
  observe({
    if (requireNamespace("wordcloud2", quietly = TRUE)) {
      wc2_render <- get("renderWordcloud2", envir = asNamespace("wordcloud2"))
      wc2_fn <- get("wordcloud2", envir = asNamespace("wordcloud2"))
      output$story_terms_wordcloud <- wc2_render({
        tryCatch({
          df <- story_terms_counts()
          if (nrow(df) == 0) df <- data.frame(term = c('no','terms','found'), freq = c(3,2,1))
          wc2_fn(data.frame(word = df$term, freq = df$freq), size = 2.2)
        }, error = function(e) {
          NULL
        })
      })
    }
  })

  output$story_terms_bar <- renderPlotly({
    df <- story_terms_counts() %>% dplyr::arrange(dplyr::desc(freq))
    plot_ly(df, x = ~freq, y = ~reorder(term, freq), type = 'bar', orientation = 'h', marker = list(color = '#6c5ce7')) %>%
      layout(title = 'Terminology Mentions', xaxis = list(title = 'Count'), yaxis = list(title = 'Term'))
  })

  # Archive Images Gallery with Navigation
  output$overview_images <- renderUI({
    img_dir <- "content/images"
    if (!dir.exists(img_dir)) {
      return(p("No images directory found. Create 'content/images/' to add archive materials.", 
               style = "color: #95a5a6; font-style: italic;"))
    }
    
    # Get all image files
    img_files <- list.files(img_dir, pattern = "\\.(jpg|jpeg|png|gif|webp)$", 
                           ignore.case = TRUE, full.names = FALSE)
    
    if (length(img_files) == 0) {
      return(p("No images found. Upload images or place them in 'content/images/'.", 
               style = "color: #95a5a6; font-style: italic;"))
    }
    
    # Current image index (use input$current_image_index or default to 1)
    current_idx <- isolate(input$current_image_index %||% 1)
    if (current_idx > length(img_files)) current_idx <- 1
    
    # Current image
    current_img <- img_files[current_idx]
    img_path <- file.path(img_dir, current_img)
    
    # Image descriptions
    descriptions <- list(
      "act_xxvi_1868_lock_hospitals" = "Act No. XXVI of 1868: Legislation enabling municipalities to provide for Lock-Hospitals. This act expanded the state's power to establish and maintain lock hospitals for the prevention of contagious venereal disease.",
      "lock_hospitals_receipts_1873" = "Statement No. III showing the receipts and expenditure on account of Lock Hospitals during the year 1873, documenting the financial administration of the surveillance system across different stations.",
      "bassein_hospital_records_1875" = "Amended Annual Statement from the Lock-hospital at Bassein (1875) showing detailed records of registered women, diseases diagnosed, and monthly statistics - a stark example of how women's bodies were transformed into administrative data.",
      "lock_hospital_buildings" = "Architectural renderings of Lock Hospital buildings, showing the physical infrastructure of medical surveillance. These institutions combined medical care with mechanisms of control and containment."
    )
    
    img_name <- gsub("\\.(jpg|jpeg|png|gif|webp)$", "", current_img, ignore.case = TRUE)
    img_description <- descriptions[[img_name]] %||% img_name
    
    # Create navigation UI
    div(
      style = "max-width: 800px; margin: 0 auto; text-align: center;",
      # Image counter
      div(
        style = "margin-bottom: 15px; font-size: 14px; color: #7f8c8d;",
        sprintf("Image %d of %d", current_idx, length(img_files))
      ),
      # Image container
      div(
        style = "position: relative; margin: 20px 0; background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);",
        # Navigation buttons
        div(
          style = "position: absolute; left: 10px; top: 50%; transform: translateY(-50%); z-index: 2;",
          if (current_idx > 1) 
            actionButton(
              inputId = "prev_image",
              label = HTML("&#10094;"),
              style = "background: rgba(0,0,0,0.6); color: white; border: none; border-radius: 50%; width: 40px; height: 40px;"
            )
        ),
        div(
          style = "position: absolute; right: 10px; top: 50%; transform: translateY(-50%); z-index: 2;",
          if (current_idx < length(img_files))
            actionButton(
              inputId = "next_image",
              label = HTML("&#10095;"),
              style = "background: rgba(0,0,0,0.6); color: white; border: none; border-radius: 50%; width: 40px; height: 40px;"
            )
        ),
        # Main image
        tags$img(
          src = img_path,
          style = "max-width: 100%; height: auto; border-radius: 4px;",
          onclick = sprintf("window.open('%s', '_blank')", img_path),
          alt = img_name
        )
      ),
      # Image caption with description
      div(
        style = "margin-top: 15px; padding: 20px; background: #f8f9fa; border-radius: 4px;",
        h4(tools::toTitleCase(gsub("_", " ", img_name)), 
           style = "margin: 0 0 10px 0; color: #2c3e50; font-size: 18px; font-weight: 600;"),
        p(img_description,
          style = "margin: 0; color: #34495e; font-size: 14px; line-height: 1.6;")
      )
    )
  })

  # ---------------------
  # Temporal-Spatial Correlation Metrics
  # ---------------------
  correlation_data <- reactive({
    w <- women_df()
    t <- troops_df()
    
    if (nrow(w) == 0 || nrow(t) == 0) return(data.frame())
    # Defensive: if expected derived columns are missing, skip heavy analysis
    required_w_cols <- c('avg_registered', 'women_added')
    if (!all(required_w_cols %in% names(w))) {
      message('correlation_data: missing required women columns; skipping correlation computation')
      return(data.frame())
    }
    # Defensive: ensure troop columns required for correlation exist
    required_t_cols <- c('avg_strength', 'total_admissions')
    if (!all(required_t_cols %in% names(t))) {
      message('correlation_data: missing required troop columns; skipping correlation computation')
      return(data.frame())
    }
    
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

  # =======================
  # Hospital Operations Data (cleaned & enriched)
  # =======================
  hospital_ops_enriched <- reactive({
    # Join hospital_operations with hospital_notes for operational details
    ops <- ops_df()
    notes <- notes_df()
    
    if (nrow(ops) == 0) {
      message("hospital_ops_enriched: ops_df() returned 0 rows")
      return(data.frame())
    }
    if (nrow(notes) == 0) {
      message("hospital_ops_enriched: notes_df() returned 0 rows")
      return(data.frame())
    }
    
    # Join by hid
    joined <- ops %>%
      dplyr::left_join(notes, by = "hid", suffix = c("", "_note"))
    
    if (nrow(joined) == 0) {
      message("hospital_ops_enriched: join produced 0 rows")
      return(data.frame())
    }
    
    # Clean and extract data
    result <- tryCatch({
      joined %>%
        dplyr::mutate(
          # Clean text fields (remove special characters, normalize)
          ops_inspection_clean = .strip_specials(ops_inspection_regularity),
          ops_unlicensed_clean = .strip_specials(ops_unlicensed_control_notes),
          ops_committee_clean = .strip_specials(ops_committee_activity_notes),
          remarks_clean = .clean_remarks(.strip_specials(remarks)),
          
          # Extract absentee punishment counts from inspection notes
          absentees_punished = suppressWarnings(as.integer(stringr::str_extract(
            tolower(paste0(
              ifelse(is.na(ops_inspection_regularity), "", ops_inspection_regularity), " ",
              ifelse(is.na(ops_inspection_clean), "", ops_inspection_clean)
            )),
            "(?<=\\b)(\\d+)(?=\\s*absentees?\\s*punished)"
          ))),
          
          # Normalize categorical fields
          inspection_freq_norm = dplyr::case_when(
            is.na(inspection_freq) | inspection_freq == "" ~ NA_character_,
            tolower(inspection_freq) %in% c("weekly", "week") ~ "Weekly",
            tolower(inspection_freq) %in% c("daily", "day") ~ "Daily",
            tolower(inspection_freq) %in% c("monthly", "month") ~ "Monthly",
            tolower(inspection_freq) %in% c("fortnightly", "fortnight", "bi-weekly") ~ "Fortnightly",
            tolower(inspection_freq) %in% c("irregular", "sporadic", "infrequent") ~ "Irregular",
            TRUE ~ "Other"
          ),
          
          unlicensed_control_norm = dplyr::case_when(
            is.na(unlicensed_control_type) | unlicensed_control_type == "" ~ NA_character_,
            tolower(unlicensed_control_type) == "police_action" ~ "Police Action",
            tolower(unlicensed_control_type) == "special_constables" ~ "Special Constables",
            tolower(unlicensed_control_type) == "other" ~ "Other Methods",
            TRUE ~ "Other Methods"
          ),
          
          committee_supervision_norm = dplyr::case_when(
            is.na(committee_supervision) | committee_supervision == "" ~ NA_character_,
            grepl("magistrate", tolower(committee_supervision), fixed = FALSE) ~ "Magistrate Oversight",
            grepl("subcommittee.*regular", tolower(committee_supervision), fixed = FALSE) ~ "Regular Subcommittee",
            grepl("subcommittee.*irregular", tolower(committee_supervision), fixed = FALSE) ~ "Irregular Subcommittee",
            grepl("subcommittee", tolower(committee_supervision), fixed = FALSE) ~ "Subcommittee",
            grepl("committee", tolower(committee_supervision), fixed = FALSE) ~ "Committee",
            TRUE ~ "Other"
          ),
          
          # Create administrative intensity score (0-3)
          admin_intensity = (
            ((!is.na(inspection_freq_norm)) & (inspection_freq_norm %in% c("Weekly", "Daily"))) * 1 +
            ((!is.na(unlicensed_control_norm)) & (unlicensed_control_norm == "Police Action")) * 1 +
            ((!is.na(committee_supervision_norm)) & (committee_supervision_norm %in% c("Regular Subcommittee", "Committee"))) * 1
          ),
          # Staff mentions (proxy): count occurrences in combined cleaned text
          .combined_text = tolower(paste0(
            ifelse(is.na(ops_committee_clean), "", ops_committee_clean), " ",
            ifelse(is.na(ops_unlicensed_clean), "", ops_unlicensed_clean), " ",
            ifelse(is.na(remarks_clean), "", remarks_clean)
          )),
          staff_male_mentions = (
            stringr::str_count(.combined_text, "\\b(surgeon|apothecary|doctor|medical officer|secretary)\\b")
          ),
          staff_female_mentions = (
            stringr::str_count(.combined_text, "\\b(matron|nurse|midwife|ayah)\\b")
          )
        ) %>%
        dplyr::filter(!is.na(station), !is.na(year))
    }, error = function(e) {
      message("Error in hospital_ops_enriched: ", e$message)
      return(data.frame())
    })
    
    if (nrow(result) == 0) {
      message("hospital_ops_enriched: final result has 0 rows")
    } else {
      message("hospital_ops_enriched: returning ", nrow(result), " rows")
    }
    
    result
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
      "ops_inspection_regularity","ops_unlicensed_control_notes","ops_committee_activity_notes","remarks" # nolint
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
    # Interactive time series: women brought to hospital (admissions via disease cases)
    # with vertical markers for key Acts (1864, 1868, 1880) and optional overlay of registration adds
    w <- women_df()
    validate(need(nrow(w) > 0, "No women_admission data found"))

    yearly <- w %>%
      dplyr::mutate(
        year = as.integer(year),
        women_brought = rowSums(cbind(
          suppressWarnings(as.numeric(disease_primary_syphilis)),
          suppressWarnings(as.numeric(disease_secondary_syphilis)),
          suppressWarnings(as.numeric(disease_gonorrhoea)),
          suppressWarnings(as.numeric(disease_leucorrhoea))
        ), na.rm = TRUE)
      ) %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(
        women_brought = sum(women_brought, na.rm = TRUE),
        women_added = sum(suppressWarnings(as.numeric(women_added)), na.rm = TRUE),
        .groups = 'drop'
      ) %>%
      dplyr::filter(!is.na(year)) %>%
      dplyr::arrange(year)

    validate(need(nrow(yearly) > 0, "No yearly aggregates available"))

    p <- plot_ly(yearly, x = ~year) %>%
      add_trace(y = ~women_brought, name = 'Women brought to hospital', type = 'scatter', mode = 'lines+markers',
                line = list(color = '#e74c3c', width = 2), marker = list(size = 7, color = '#e74c3c')) %>%
      add_trace(y = ~women_added, name = 'Women added to registration', type = 'scatter', mode = 'lines',
                line = list(color = '#7f8c8d', dash = 'dot', width = 1.5)) %>%
      layout(
        title = list(text = 'Women Brought to Lock Hospitals (with Acts markers)', font = list(size = 16)),
        xaxis = list(title = 'Year'),
        yaxis = list(title = 'Number of Women'),
        legend = list(orientation = 'h'),
        hovermode = 'x unified',
        shapes = list(
          # 1864: Early CD Acts (XII and XXII)
          list(type = 'line', x0 = 1864, x1 = 1864, y0 = 0, y1 = 1, yref = 'paper',
               line = list(color = '#3498db', width = 2, dash = 'dash')),
          # 1868: Act XIV of 1868
          list(type = 'line', x0 = 1868, x1 = 1868, y0 = 0, y1 = 1, yref = 'paper',
               line = list(color = '#e67e22', width = 2, dash = 'dash')),
          # 1880: Act III of 1880
          list(type = 'line', x0 = 1880, x1 = 1880, y0 = 0, y1 = 1, yref = 'paper',
               line = list(color = '#9b59b6', width = 2, dash = 'dash'))
        ),
        annotations = list(
          list(x = 1864, y = 1, xref = 'x', yref = 'paper', text = 'CD Acts (1864)',
               showarrow = FALSE, xanchor = 'left', yanchor = 'bottom', font = list(color = '#3498db', size = 10)),
          list(x = 1868, y = 1, xref = 'x', yref = 'paper', text = 'Act XIV (1868)',
               showarrow = FALSE, xanchor = 'left', yanchor = 'bottom', font = list(color = '#e67e22', size = 10)),
          list(x = 1880, y = 1, xref = 'x', yref = 'paper', text = 'Act III (1880)',
               showarrow = FALSE, xanchor = 'left', yanchor = 'bottom', font = list(color = '#9b59b6', size = 10))
        )
      )

    p
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
  # Military-Medical: Interactive Surveillance Pipeline (Sankey diagram)
  output$med_surveillance_sankey <- renderSankeyNetwork({
    # Get filtered year range
    year_range <- input$pipeline_years
    if (is.null(year_range)) year_range <- c(1860, 1890)
    
    # Get aggregated data by year and station with Act info
    df <- dbGetQuery(conn(), "
      SELECT 
        t.station,
        t.year,
        ho.act,
        t.region,
        SUM(t.total_admissions) as military_vd,
        SUM(w.women_added) as women_admitted,
        SUM(w.avg_registered) as women_registered,
        SUM(w.fined_count + w.imprisonment_count) as punitive_actions
      FROM troops t
      LEFT JOIN hospital_operations ho ON t.station = ho.station AND t.year = ho.year
      LEFT JOIN women_admission w ON t.station = w.station AND t.year = w.year
      WHERE t.year >= ? AND t.year <= ?
      GROUP BY t.station, t.year, ho.act, t.region
      ORDER BY t.year
    ", params = list(year_range[1], year_range[2]))
    
    validate(need(nrow(df) > 0, "No data available for selected year range"))
    
    # Map Acts to readable names
    df$act_name <- ifelse(is.na(df$act) | df$act == "None", "No Act", 
                   ifelse(df$act == "Act XXII of 1864", "Act XXII (1864)",
                   ifelse(df$act == "Act VI of 1868", "Act VI (1868)",
                   ifelse(df$act == "Act XIV of 1868", "Act XIV (1868)",
                   ifelse(df$act == "Act III of 1880", "Act III (1880)", df$act)))))
    
    # Aggregate flows
    agg <- df %>%
      group_by(act_name) %>%
      summarise(
        military_vd = sum(military_vd, na.rm = TRUE),
        women_admitted = sum(women_admitted, na.rm = TRUE),
        women_registered = sum(women_registered, na.rm = TRUE),
        stations = n_distinct(station),
        .groups = 'drop'
      )
    
    # Create Sankey nodes
    nodes <- data.frame(
      name = c(
        "Military VD Cases",           # 0
        "Act XXII (1864)",             # 1
        "Act VI (1868)",               # 2
        "Act XIV (1868)",              # 3
        "Act III (1880)",              # 4
        "No Act",                      # 5
        "Women Admitted",              # 6
        "Women Registered"             # 7
      ),
      stringsAsFactors = FALSE
    )
    
    # Create links (flows) - collect as list then convert to df
    links_list <- list()
    
    # Precompute totals for percentage calculations
    total_military <- sum(agg$military_vd, na.rm = TRUE)
    total_women_adm <- sum(agg$women_admitted, na.rm = TRUE)

    # Flow 1: Military VD → Acts (or No Act), as percentage of total military VD cases
    if (nrow(agg) > 0) {
      for (i in seq_len(nrow(agg))) {
        act <- agg$act_name[i]
        val <- agg$military_vd[i]
        if (!is.na(val) && val > 0 && total_military > 0) {
          target_idx <- which(nodes$name == act) - 1  # 0-indexed
          if (length(target_idx) > 0) {
            pct <- round(100 * val / total_military, 1)
            links_list[[length(links_list) + 1]] <- list(
              source = 0,
              target = target_idx,
              value = pct,
              group = act
            )
          }
        }
      }
    }
    
    # Flow 2: Acts → Women Admitted, as percentage of total women admitted
    if (nrow(agg) > 0) {
      for (i in seq_len(nrow(agg))) {
        act <- agg$act_name[i]
        val <- agg$women_admitted[i]
        if (!is.na(val) && val > 0 && total_women_adm > 0) {
          source_idx <- which(nodes$name == act) - 1
          if (length(source_idx) > 0) {
            pct <- round(100 * val / total_women_adm, 1)
            links_list[[length(links_list) + 1]] <- list(
              source = source_idx,
              target = 6,  # Women Admitted
              value = pct,
              group = act
            )
          }
        }
      }
    }
    
    # Flow 3: Women Admitted → Women Registered, as percentage of women admitted
    total_admitted <- sum(agg$women_admitted, na.rm = TRUE)
    total_registered <- sum(agg$women_registered, na.rm = TRUE)
    if (!is.na(total_admitted) && !is.na(total_registered) && 
        total_admitted > 0 && total_registered > 0) {
      pct_reg <- round(100 * total_registered / total_admitted, 1)
      links_list[[length(links_list) + 1]] <- list(
        source = 6,
        target = 7,
        value = pct_reg,
        group = "surveillance"
      )
    }
    
    # Convert list to data frame
    validate(need(length(links_list) > 0, "No flows to display for selected year range"))
    
    links <- do.call(rbind, lapply(links_list, function(x) {
      data.frame(
        source = as.integer(x$source),
        target = as.integer(x$target),
        value = as.numeric(x$value),
        group = as.character(x$group),
        stringsAsFactors = FALSE
      )
    }))
    
    # Create Sankey diagram
    sankeyNetwork(
      Links = links,
      Nodes = nodes,
      Source = "source",
      Target = "target",
      Value = "value",
      NodeID = "name",
      units = "%",
      fontSize = 13,
      nodeWidth = 25,
      nodePadding = 15,
      height = 550,
      width = NULL,
      sinksRight = TRUE,
      iterations = 100,
      LinkGroup = "group",
      colourScale = JS("
        d3.scaleOrdinal()
          .domain(['Act XXII (1864)', 'Act VI (1868)', 'Act XIV (1868)', 'Act III (1880)', 'No Act', 'surveillance'])
          .range(['#e74c3c', '#f39c12', '#9b59b6', '#2c3e50', '#bdc3c7', '#3498db'])
      ")
    )
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
  
  # Acts Animated Map
  output$acts_animated_map <- renderLeaflet({
    req(input$acts_year)  # Require year input
    
    year_selected <- input$acts_year
    show_lines <- isTRUE(input$show_network_lines)
    act_filter <- if (is.null(input$network_act_filter)) "all" else input$network_act_filter
    
    # Get all stations with coordinates
    stations <- stations_df()
    if (nrow(stations) == 0) {
      return(leaflet() %>% addTiles() %>% setView(lng = 80, lat = 20, zoom = 4))
    }
    
      # Detect station name column and lat/lon columns
      station_col <- if ("name" %in% names(stations)) "name" else if ("station" %in% names(stations)) "station" else NULL
      lat_col <- if ("latitude" %in% names(stations)) "latitude" else if ("lat" %in% names(stations)) "lat" else NULL
      lon_col <- if ("longitude" %in% names(stations)) "longitude" else if ("lon" %in% names(stations)) "lon" else if ("lng" %in% names(stations)) "lng" else NULL
    
      if (is.null(station_col) || is.null(lat_col) || is.null(lon_col)) {
      return(leaflet() %>% addTiles() %>% setView(lng = 80, lat = 20, zoom = 4))
    }
    
    # Get Acts cumulative data up to selected year
    acts_cumulative <- dbGetQuery(conn(), sprintf("
      SELECT station, act, MIN(year) as first_year, MAX(year) as last_year, COUNT(*) as total_records
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND TRIM(act) != ''
        AND year <= %d
      GROUP BY station, act
    ", year_selected))
    
    if (nrow(acts_cumulative) == 0) {
      # Show empty map with message
      return(leaflet() %>% addTiles() %>% setView(lng = 80, lat = 20, zoom = 4))
    }
    
    # Apply Act filter
    if (act_filter != "all") {
      acts_cumulative <- acts_cumulative %>% filter(act == act_filter)
      if (nrow(acts_cumulative) == 0) {
        return(leaflet() %>% addTiles() %>% setView(lng = 80, lat = 20, zoom = 4))
      }
    }
    
      # Normalize names and join with station coordinates robustly
      acts_norm <- acts_cumulative %>%
        dplyr::mutate(station_key = tolower(trimws(station)))
      stations_norm <- stations %>%
        dplyr::mutate(station_key = tolower(trimws(!!sym(station_col))))
    
      acts_with_coords <- acts_norm %>%
        dplyr::inner_join(stations_norm, by = "station_key") %>%
      filter(!is.na(!!sym(lat_col)), !is.na(!!sym(lon_col))) %>%
      mutate(
        lat = as.numeric(!!sym(lat_col)), 
        lon = as.numeric(!!sym(lon_col))
      ) %>%
      filter(lat >= -90, lat <= 90, lon >= -180, lon <= 180)
    
    if (nrow(acts_with_coords) == 0) {
      return(leaflet() %>% addTiles() %>% setView(lng = 80, lat = 20, zoom = 4))
    }
    
    # Get active stations for this specific year
    acts_this_year <- dbGetQuery(conn(), sprintf("
      SELECT DISTINCT station
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND TRIM(act) != ''
        AND year = %d
    ", year_selected))
    
    active_stations <- if (nrow(acts_this_year) > 0) acts_this_year$station else character(0)
    
    # Mark active stations
    acts_with_coords <- acts_with_coords %>%
      mutate(active_this_year = station %in% active_stations)
    
    # Color palette
    act_colors <- c(
      "Act XIV of 1868" = "#e74c3c",
      "Act XXII of 1864" = "#3498db", 
        "Act XII of 1864" = "#3498db",
      "Act III of 1880" = "#2ecc71",
      "Voluntary System" = "#f39c12",
      "CD Act" = "#e67e22",
      "Cantonment Act" = "#9b59b6"
    )
    
    # Create visualization attributes
    acts_with_coords <- acts_with_coords %>%
      mutate(
        color = ifelse(act %in% names(act_colors), act_colors[act], "#95a5a6"),
        opacity = ifelse(active_this_year, 0.9, 0.3),
        radius = pmax(5, sqrt(total_records) * 2),
        popup_text = paste0(
          "<b>", station, "</b><br>",
          "<b>Act:</b> ", act, "<br>",
          "<b>First Year:</b> ", first_year, "<br>",
          "<b>Last Year:</b> ", last_year, "<br>",
          "<b>Records:</b> ", total_records,
          ifelse(active_this_year, 
                 paste0("<br><b style='color:#27ae60'>Active in ", year_selected, "</b>"), 
                 paste0("<br><span style='color:#999'>Inactive in ", year_selected, "</span>"))
        ),
        label_text = paste0(station, ": ", act)
      )
    
    # Create base map
    m <- leaflet(acts_with_coords) %>% 
      addTiles() %>%
      addCircleMarkers(
        ~lon, ~lat, 
        radius = ~radius,
        color = ~color,
        fillOpacity = ~opacity,
        stroke = TRUE,
        weight = 1,
        popup = ~popup_text,
        label = ~label_text
      )
    
    m
  })
  
  # Populate Act filter choices dynamically
  observe({
    acts_list <- dbGetQuery(conn(), "
      SELECT DISTINCT act
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND TRIM(act) != ''
      ORDER BY act
    ")
    
    if (nrow(acts_list) > 0) {
      choices <- c("All Acts" = "all", setNames(acts_list$act, acts_list$act))
      updateSelectInput(session, "network_act_filter", choices = choices)
    }
  })
  
  # Acts Year Summary
  output$acts_year_summary <- renderPlotly({
    year_selected <- input$acts_year
    
    acts_summary <- dbGetQuery(conn(), sprintf("
      SELECT act, COUNT(DISTINCT station) as stations
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND TRIM(act) != ''
        AND year <= %d
      GROUP BY act
      ORDER BY stations DESC
    ", year_selected))
    
    if (nrow(acts_summary) == 0) {
      return(plot_ly() %>% 
        add_annotations(text = paste("No Acts data for", year_selected), 
                       showarrow = FALSE, 
                       font = list(size = 16)))
    }
    
    p <- plot_ly(acts_summary, x = ~act, y = ~stations, type = 'bar',
                marker = list(color = '#27ae60')) %>%
      layout(
        title = paste("Cumulative Acts Implementation by", year_selected),
        xaxis = list(title = "Act"),
        yaxis = list(title = "Number of Stations"),
        showlegend = FALSE
      )
    p
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
    
    # Count each Act separately
    acts_counts <- dbGetQuery(conn(), "
      SELECT act, COUNT(DISTINCT station) as station_count, COUNT(*) as total_records
      FROM hospital_operations
      WHERE act IS NOT NULL AND act != 'None' AND TRIM(act) != ''
      GROUP BY act
      ORDER BY station_count DESC
    ")
    
    acts_text <- ""
    if (nrow(acts_counts) > 0) {
      for (i in 1:nrow(acts_counts)) {
        acts_text <- paste0(acts_text, 
          "   • ", acts_counts$act[i], ": ", 
          fmt(acts_counts$station_count[i]), " stations (", 
          fmt(acts_counts$total_records[i]), " records)\n")
      }
    } else {
      acts_text <- "   • No Acts data available\n"
    }
    
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
      "CONTAGIOUS DISEASES ACTS IMPLEMENTATION\n",
      acts_text,
      "   • Compulsory registration, examination, and detention\n",
      "</pre>"
    )
    HTML(summary_text)
  })

  # Stations Map
  output$stations_map <- renderLeaflet({
    st <- stations_df()
    message('renderLeaflet: stations_map - stations rows = ', nrow(st))
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
    message('renderLeaflet: stations_map - geolocated rows = ', nrow(st2))
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
  
  # =====================
  # Story Tab Visualizations
  # =====================
  
  # Story: Total stats summary
  output$story_total_stats <- renderUI({
    n_docs <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM documents")$count
    n_stations <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM stations")$count
    n_women <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM women_admission")$count
    n_troops <- dbGetQuery(conn(), "SELECT COUNT(*) as count FROM troops")$count
    
    # Calculate year ranges and missing years for all datasets
    women <- women_df()
    troops <- troops_df()
    ops <- hospital_ops_enriched()
    
    # Helper function to get missing years
    get_missing_years <- function(years) {
      years <- sort(unique(na.omit(years)))
      if (length(years) < 2) return(character(0))
      yr_min <- min(years)
      yr_max <- max(years)
      expected <- seq(yr_min, yr_max)
      missing <- setdiff(expected, years)
      if (length(missing) > 0) return(as.character(missing))
      return(character(0))
    }
    
    women_years <- if (nrow(women) > 0 && "year" %in% names(women)) women$year else numeric(0)
    troops_years <- if (nrow(troops) > 0 && "year" %in% names(troops)) troops$year else numeric(0)
    ops_years <- if (nrow(ops) > 0 && "year" %in% names(ops)) ops$year else numeric(0)
    
    women_missing <- get_missing_years(women_years)
    troops_missing <- get_missing_years(troops_years)
    ops_missing <- get_missing_years(ops_years)
    
    # Build missing years summary HTML
    missing_summary <- ""
    if (length(women_missing) > 0 || length(troops_missing) > 0 || length(ops_missing) > 0) {
      missing_parts <- c()
      if (length(women_missing) > 0) {
        missing_parts <- c(missing_parts, paste0("<b>Women:</b> ", paste(women_missing, collapse = ", ")))
      }
      if (length(troops_missing) > 0) {
        missing_parts <- c(missing_parts, paste0("<b>Troops:</b> ", paste(troops_missing, collapse = ", ")))
      }
      if (length(ops_missing) > 0) {
        missing_parts <- c(missing_parts, paste0("<b>Hospital Ops:</b> ", paste(ops_missing, collapse = ", ")))
      }
      
      missing_summary <- paste0(
        "<div style='margin-top:20px; padding:15px; background:#fff3cd; border-left:4px solid #e74c3c; border-radius:4px;'>",
        "<div style='font-weight:bold; color:#856404; margin-bottom:8px;'>⚠ Missing Years in Data Coverage</div>",
        "<div style='color:#856404; font-size:0.95em;'>",
        paste(missing_parts, collapse = "<br>"),
        "</div>",
        "</div>"
      )
    }
    
    HTML(paste0(
      "<div>",
      "<div class='row' style='margin-bottom:0;'>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#3498db;'>", n_stations, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Stations</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#e74c3c;'>", n_women, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Women Records</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#f39c12;'>", n_troops, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Troop Records</div>",
      "  </div>",
      "  <div class='col-sm-3' style='text-align:center;'>",
      "    <div style='font-size:3em;font-weight:bold;color:#9b59b6;'>", n_docs, "</div>",
      "    <div style='font-size:1.1em;color:#7f8c8d;'>Source Documents</div>",
      "  </div>",
      "</div>",
      missing_summary,
      "</div>"
    ))
  })
  
  # Story: Overview map
  output$story_map_overview <- renderLeaflet({
    st <- stations_df()
    req(nrow(st) > 0)
    
    lat_col <- 'latitude'; lon_col <- 'longitude'
    if (all(c('lat','lon') %in% names(st))) { lat_col <- 'lat'; lon_col <- 'lon' }
    
    st2 <- st %>%
      dplyr::filter(!is.na(.data[[lat_col]]), !is.na(.data[[lon_col]])) %>%
      dplyr::mutate(lat = as.numeric(.data[[lat_col]]), lon = as.numeric(.data[[lon_col]]))
    
    leaflet(st2) %>%
      addTiles() %>%
      setView(lng = 78.9629, lat = 20.5937, zoom = 5) %>%
      addCircleMarkers(
        ~lon, ~lat,
        radius = 6,
        color = "#e74c3c",
        fillOpacity = 0.7,
        stroke = TRUE,
        weight = 1,
        popup = ~paste0("<b>", name, "</b><br>Region: ", region)
      )
  })
  
  # Story: Acts timeline
  output$story_acts_timeline <- renderUI({
    HTML("
      <div style='padding: 20px;'>
        <div style='margin-bottom: 30px;'>
          <div style='font-size: 1.5em; font-weight: bold; color: #3498db;'>1864 - Act XXII</div>
          <div style='font-size: 1.1em; color: #555; margin-top: 10px;'>
            Established compulsory registration and examination of women in cantonment areas.
          </div>
        </div>
        <div style='margin-bottom: 30px;'>
          <div style='font-size: 1.5em; font-weight: bold; color: #e67e22;'>1868 - Act XIV</div>
          <div style='font-size: 1.1em; color: #555; margin-top: 10px;'>
            Expanded surveillance to civilian areas and increased penalties for non-compliance.
          </div>
        </div>
        <div style='margin-bottom: 30px;'>
          <div style='font-size: 1.5em; font-weight: bold; color: #9b59b6;'>1880 - Act III</div>
          <div style='font-size: 1.1em; color: #555; margin-top: 10px;'>
            Introduced after repeal campaigns, maintained surveillance under the guise of 'voluntary' registration.
          </div>
        </div>
      </div>
    ")
  })
  
  # Handle "Explore Data" button click
  observeEvent(input$switch_to_tables, {
    updateTabItems(session, "sidebar", "tables")
  })
  
  # =====================
  # End Story Tab
  # =====================
  
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
  
  # =====================
  # Hospital Operations Visualizations
  # =====================
  
  # Debug info
  output$ops_debug_info <- renderText({
    ops <- hospital_ops_enriched()
    paste0(
      "Hospital Operations Data Status:\n",
      "Total rows: ", nrow(ops), "\n",
      if (nrow(ops) > 0) {
        paste0(
          "Columns: ", paste(names(ops), collapse = ", "), "\n",
          "With inspection_freq_norm: ", sum(!is.na(ops$inspection_freq_norm)), "\n",
          "With unlicensed_control_norm: ", sum(!is.na(ops$unlicensed_control_norm)), "\n",
          "With committee_supervision_norm: ", sum(!is.na(ops$committee_supervision_norm)), "\n",
          "With absentees_punished: ", sum(!is.na(ops$absentees_punished)), "\n",
          "Sample years: ", paste(head(sort(unique(ops$year)), 5), collapse = ", ")
        )
      } else {
        "No data available - check console messages for details."
      }
    )
  })
  
  # Inspection Frequency Timeline
  output$ops_inspection_timeline <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    timeline <- ops %>%
      dplyr::filter(!is.na(inspection_freq_norm)) %>%
      dplyr::group_by(year, inspection_freq_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop') %>%
      dplyr::arrange(year)
    
    validate(need(nrow(timeline) > 0, "No inspection frequency data"))
    
    plot_ly(timeline, x = ~year, y = ~count, color = ~inspection_freq_norm, type = 'scatter', mode = 'lines+markers',
            colors = c("Weekly" = "#27ae60", "Daily" = "#16a085", "Fortnightly" = "#f39c12", 
                       "Monthly" = "#e67e22", "Irregular" = "#e74c3c", "Other" = "#95a5a6")) %>%
      layout(title = 'Inspection Frequency Over Time',
             xaxis = list(title = 'Year'),
             yaxis = list(title = 'Number of Stations'),
             legend = list(orientation = 'h'))
  })
  
  # Inspection Frequency by Region
  output$ops_inspection_by_region <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    by_region <- ops %>%
      dplyr::filter(!is.na(inspection_freq_norm), !is.na(region)) %>%
      dplyr::group_by(region, inspection_freq_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop')
    
    validate(need(nrow(by_region) > 0, "No regional inspection data"))
    
    plot_ly(by_region, x = ~region, y = ~count, color = ~inspection_freq_norm, type = 'bar',
            colors = c("Weekly" = "#27ae60", "Daily" = "#16a085", "Fortnightly" = "#f39c12", 
                       "Monthly" = "#e67e22", "Irregular" = "#e74c3c", "Other" = "#95a5a6")) %>%
      layout(title = 'Inspection Regimes by Region',
             xaxis = list(title = 'Region'),
             yaxis = list(title = 'Number of Records'),
             barmode = 'stack',
             legend = list(orientation = 'h'))
  })
  
  # Unlicensed Control Methods Distribution
  output$ops_unlicensed_methods <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    methods <- ops %>%
      dplyr::filter(!is.na(unlicensed_control_norm)) %>%
      dplyr::group_by(unlicensed_control_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop') %>%
      dplyr::arrange(desc(count))
    
    validate(need(nrow(methods) > 0, "No unlicensed control data"))
    
    plot_ly(methods, x = ~reorder(unlicensed_control_norm, count), y = ~count, type = 'bar',
            marker = list(color = '#e74c3c')) %>%
      layout(title = 'Methods for Controlling Unlicensed Women',
             xaxis = list(title = ''),
             yaxis = list(title = 'Number of Records'))
  })
  
  # Unlicensed Control by Act
  output$ops_unlicensed_by_act <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    by_act <- ops %>%
      dplyr::filter(!is.na(unlicensed_control_norm), !is.na(act)) %>%
      dplyr::group_by(act, unlicensed_control_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop')
    
    validate(need(nrow(by_act) > 0, "No Act-specific unlicensed control data"))
    
    plot_ly(by_act, x = ~act, y = ~count, color = ~unlicensed_control_norm, type = 'bar',
            colors = c("Police Action" = "#e74c3c", "Special Constables" = "#f39c12", "Other Methods" = "#95a5a6")) %>%
      layout(title = 'Unlicensed Control Methods by Act',
             xaxis = list(title = 'Act'),
             yaxis = list(title = 'Number of Records'),
             barmode = 'stack',
             legend = list(orientation = 'h'))
  })
  
  # Committee Oversight Distribution
  output$ops_committee_distribution <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    oversight <- ops %>%
      dplyr::filter(!is.na(committee_supervision_norm)) %>%
      dplyr::group_by(committee_supervision_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop') %>%
      dplyr::arrange(desc(count))
    
    validate(need(nrow(oversight) > 0, "No committee oversight data"))
    
    plot_ly(oversight, labels = ~committee_supervision_norm, values = ~count, type = 'pie',
            textinfo = 'label+percent',
            marker = list(colors = c('#3498db', '#2ecc71', '#f39c12', '#e67e22', '#9b59b6', '#95a5a6'))) %>%
      layout(title = 'Administrative Oversight Structure')
  })
  
  # Committee Oversight by Region
  output$ops_committee_by_region <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    by_region <- ops %>%
      dplyr::filter(!is.na(committee_supervision_norm), !is.na(region)) %>%
      dplyr::group_by(region, committee_supervision_norm) %>%
      dplyr::summarise(count = dplyr::n(), .groups = 'drop')
    
    validate(need(nrow(by_region) > 0, "No regional committee data"))
    
    plot_ly(by_region, x = ~region, y = ~count, color = ~committee_supervision_norm, type = 'bar',
            colors = c("Magistrate Oversight" = "#3498db", "Committee" = "#2ecc71", 
                       "Regular Subcommittee" = "#f39c12", "Irregular Subcommittee" = "#e67e22",
                       "Subcommittee" = "#9b59b6", "Other" = "#95a5a6")) %>%
      layout(title = 'Oversight Structure by Region',
             xaxis = list(title = 'Region'),
             yaxis = list(title = 'Number of Records'),
             barmode = 'stack',
             legend = list(orientation = 'h'))
  })
  
  # Punishment Timeline (Absentees Punished)
  output$ops_punishment_timeline <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    punishment <- ops %>%
      dplyr::filter(!is.na(absentees_punished)) %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(
        total_punished = sum(absentees_punished, na.rm = TRUE),
        avg_punished = mean(absentees_punished, na.rm = TRUE),
        stations = dplyr::n(),
        .groups = 'drop'
      ) %>%
      dplyr::arrange(year)
    
    validate(need(nrow(punishment) > 0, "No punishment data extracted"))
    
    plot_ly(punishment, x = ~year) %>%
      add_trace(y = ~total_punished, name = 'Total Absentees Punished', type = 'scatter', mode = 'lines+markers',
                line = list(color = '#e74c3c', width = 2), marker = list(size = 8)) %>%
      add_trace(y = ~avg_punished, name = 'Average per Station', type = 'scatter', mode = 'lines',
                line = list(color = '#f39c12', dash = 'dot', width = 2), yaxis = 'y2') %>%
      layout(title = 'Absentee Punishments Over Time (Resistance Indicator)',
             xaxis = list(title = 'Year'),
             yaxis = list(title = 'Total Punished'),
             yaxis2 = list(title = 'Average per Station', overlaying = 'y', side = 'right'),
             legend = list(orientation = 'h'))
  })
  
  # Punishment by Station (Top 15)
  output$ops_punishment_by_station <- renderPlotly({
    ops <- hospital_ops_enriched()
    validate(need(nrow(ops) > 0, "No hospital operations data available"))
    
    by_station <- ops %>%
      dplyr::filter(!is.na(absentees_punished)) %>%
      dplyr::group_by(station, region) %>%
      dplyr::summarise(total_punished = sum(absentees_punished, na.rm = TRUE), .groups = 'drop') %>%
      dplyr::arrange(desc(total_punished)) %>%
      dplyr::slice_head(n = 15)
    
    validate(need(nrow(by_station) > 0, "No station-level punishment data"))
    
    plot_ly(by_station, x = ~reorder(station, total_punished), y = ~total_punished, type = 'bar',
            marker = list(color = '#e74c3c'), text = ~region, hovertemplate = '%{x}<br>%{y} punished<br>Region: %{text}') %>%
      layout(title = 'Top 15 Stations by Absentee Punishments',
             xaxis = list(title = ''),
             yaxis = list(title = 'Total Absentees Punished')) %>%
      add_annotations(text = '(Proxy for resistance intensity)', xref = 'paper', yref = 'paper',
                     x = 0.5, y = 1.1, showarrow = FALSE, font = list(size = 11, color = '#7f8c8d'))
  })
  
  # (Removed) Administrative Intensity Map and status outputs at user's request

  # Staff role mentions (proxy) over time - simplified to use hospital ops directly
  output$ops_staff_mentions_timeline <- renderPlotly({
    tryCatch({
      ops <- hospital_ops_enriched()
      validate(need(nrow(ops) > 0, "No hospital operations data available"))
      
      # Check if staff mention columns exist
      if (!all(c("staff_male_mentions", "staff_female_mentions") %in% names(ops))) {
        return(plotly::plot_ly() %>% plotly::layout(
          title = "Staff mentions columns not found",
          annotations = list(x = 0.5, y = 0.5, text = "Missing staff_male_mentions or staff_female_mentions columns", showarrow = FALSE)
        ))
      }
      
      # Aggregate by year
      by_year <- ops %>%
        dplyr::filter(!is.na(year)) %>%
        dplyr::group_by(year) %>%
        dplyr::summarise(
          male = sum(staff_male_mentions, na.rm = TRUE),
          female = sum(staff_female_mentions, na.rm = TRUE),
          .groups = 'drop'
        ) %>% 
        dplyr::arrange(year)
      
      # Check if we have any mentions
      total_mentions <- sum(by_year$male, na.rm = TRUE) + sum(by_year$female, na.rm = TRUE)
      if (total_mentions == 0) {
        return(plotly::plot_ly() %>% plotly::layout(
          title = "No staff mentions found in notes",
          annotations = list(
            x = 0.5, y = 0.5, 
            text = paste0("Total rows: ", nrow(ops), " | Years: ", nrow(by_year), "<br>No role keywords (surgeon, matron, etc.) found in hospital operation notes"), 
            showarrow = FALSE
          )
        ))
      }
      
      validate(need(nrow(by_year) > 0, "No staff mentions found in notes after grouping by year"))
      
      # Create plot
      plot_ly(by_year, x = ~year) %>%
        add_trace(y = ~male, name = 'Male-coded roles', type = 'scatter', mode = 'lines+markers', 
                  line = list(color = '#2c3e50'), marker = list(size = 8)) %>%
        add_trace(y = ~female, name = 'Female-coded roles', type = 'scatter', mode = 'lines+markers', 
                  line = list(color = '#9b59b6'), marker = list(size = 8)) %>%
        layout(
          title = 'Staff Role Mentions Over Time (from hospital notes)',
          xaxis = list(title = 'Year'),
          yaxis = list(title = 'Mentions'),
          legend = list(orientation = 'h'),
          hovermode = 'x unified'
        )
    }, error = function(e) {
      plotly::plot_ly() %>% plotly::layout(
        title = "Error rendering timeline",
        annotations = list(x = 0.5, y = 0.5, text = paste0("Error: ", e$message), showarrow = FALSE)
      )
    })
  })

  # Staff role mentions by region - simplified to use hospital ops directly
  output$ops_staff_mentions_by_region <- renderPlotly({
    tryCatch({
      ops <- hospital_ops_enriched()
      validate(need(nrow(ops) > 0, "No hospital operations data available"))
      
      # Check if staff mention columns exist
      if (!all(c("staff_male_mentions", "staff_female_mentions", "region") %in% names(ops))) {
        return(plotly::plot_ly() %>% plotly::layout(
          title = "Required columns not found",
          annotations = list(x = 0.5, y = 0.5, text = "Missing staff mention or region columns", showarrow = FALSE)
        ))
      }
      
      # Aggregate by region
      by_region <- ops %>%
        dplyr::filter(!is.na(region)) %>%
        dplyr::group_by(region) %>%
        dplyr::summarise(
          male = sum(staff_male_mentions, na.rm = TRUE),
          female = sum(staff_female_mentions, na.rm = TRUE),
          .groups = 'drop'
        ) %>%
        tidyr::pivot_longer(cols = c(male, female), names_to = 'role', values_to = 'mentions')
      
      # Check if we have any mentions
      total_mentions <- sum(by_region$mentions, na.rm = TRUE)
      if (total_mentions == 0) {
        return(plotly::plot_ly() %>% plotly::layout(
          title = "No staff mentions found by region",
          annotations = list(
            x = 0.5, y = 0.5,
            text = paste0("Total rows: ", nrow(ops), " | Regions: ", length(unique(ops$region)), "<br>No role keywords found in notes"),
            showarrow = FALSE
          )
        ))
      }
      
      validate(need(nrow(by_region) > 0, "No staff mentions by region"))
      
      # Create plot
      plot_ly(by_region, x = ~region, y = ~mentions, color = ~role, type = 'bar', 
              colors = c('male' = '#2c3e50', 'female' = '#9b59b6')) %>%
        layout(
          title = 'Staff Role Mentions by Region (from hospital notes)',
          xaxis = list(title = 'Region'),
          yaxis = list(title = 'Mentions'),
          barmode = 'group',
          legend = list(orientation = 'h')
        )
    }, error = function(e) {
      plotly::plot_ly() %>% plotly::layout(
        title = "Error rendering by-region chart",
        annotations = list(x = 0.5, y = 0.5, text = paste0("Error: ", e$message), showarrow = FALSE)
      )
    })
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
