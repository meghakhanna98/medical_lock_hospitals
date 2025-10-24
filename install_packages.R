# Required R packages for Medical Lock Hospitals Shiny App
# Install these packages before running the app

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Core Shiny packages
install.packages(c(
  "shiny",
  "shinydashboard",
  "shinyWidgets"
))

# Database connectivity
install.packages(c(
  "DBI",
  "RSQLite"
))

# Data manipulation and visualization
install.packages(c(
  "dplyr",
  "ggplot2",
  "plotly",
  "DT"
))

# Data export
install.packages(c(
  "writexl",
  "jsonlite",
  "markdown"
))

# Additional utilities
install.packages(c(
  "viridis",
  "RColorBrewer",
  "leaflet",
  "httr"
))
