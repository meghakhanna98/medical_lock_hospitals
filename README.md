# Medical Lock Hospitals Data Explorer

A comprehensive Shiny web application for exploring, cleaning, and analyzing historical medical lock hospital data from British India.

## Overview

This application provides an interactive interface to work with the `medical_lock_hospitals.db` SQLite database, which contains historical data about medical lock hospitals from the late 19th century British India. The database includes information about women's admissions, troop data, hospital operations, and station reports.

## Features

### 📊 Data Overview Dashboard
- **Database Summary**: Quick statistics on all tables
- **Data Quality Assessment**: Completeness metrics and missing data analysis
- **Visual Quality Indicators**: Charts showing data integrity across tables

### 📋 Data Tables Explorer
- **Interactive Tables**: Browse all six database tables with search and pagination
- **Record Editing**: Click any row to edit individual records with real-time validation
- **Foreign Key Lookups**: Dropdown menus show related data (e.g., document names for doc_id fields)
- **Add New Records**: Create new entries with automatic form generation
- **Delete Records**: Remove entries with confirmation dialogs
- **Export Capabilities**: Download data in CSV, Excel, or JSON formats
- **Real-time Filtering**: Search and filter data dynamically

### 📈 Visualizations
- **Temporal Analysis**: Time-series plots showing data trends over years
- **Geographic Analysis**: Regional distribution and country-based analysis
- **Statistical Analysis**: Correlation analysis and activity level comparisons
- **Interactive Charts**: Powered by Plotly for dynamic exploration

### 💾 Data Export
- **Table Export**: Export any table in multiple formats
- **Custom Query Export**: Run SQL queries and export results
- **Flexible Formats**: CSV, Excel, and JSON export options

## Database Schema

The application works with six main tables:

1. **documents** - Source documents and reports
2. **stations** - Hospital stations with geographic information
3. **station_reports** - Relationships between documents and stations
4. **women_data** - Women's admission data (306 records)
5. **troop_data** - Military troop data (300 records)
6. **hospital_operations** - Hospital operational data (362 records)

## Installation & Setup

### Prerequisites
- R (version 3.6 or higher)
- RStudio (recommended)
- The `medical_lock_hospitals.db` database file

### Quick Start

1. **Install R packages**:
   ```bash
   Rscript install_packages.R
   ```

2. **Run the application**:
   ```bash
   ./run_app.sh
   ```
   
   Or manually:
   ```r
   library(shiny)
   runApp("app.R")
   ```

3. **Access the app**: Open your web browser to `http://localhost:3838`

### Manual Installation

If you prefer to install packages manually:

```r
# Install required packages
install.packages(c(
  "shiny", "shinydashboard", "shinyWidgets",
  "DBI", "RSQLite", "dplyr", "ggplot2", 
  "plotly", "DT", "writexl", "jsonlite"
))

# Run the app
shiny::runApp("app.R")
```

## Usage Guide

### Data Overview Tab
- View database statistics and data quality metrics
- Identify tables with missing or incomplete data
- Get a quick understanding of your dataset

### Data Tables Tab
- Select any table from the dropdown
- **Click on any row to edit it** - forms appear automatically
- **Foreign key columns show dropdowns** with related data (e.g., document names)
- Use "Add New Record" to create new entries
- Use "Delete Record" to remove entries (with confirmation)
- Export data directly from the interface

### Visualizations Tab
- **Temporal Analysis**: Explore trends over time
- **Geographic Analysis**: Understand regional patterns
- **Statistical Analysis**: Discover correlations and patterns

### Export Tab
- Export cleaned data in your preferred format
- Run custom SQL queries and export results
- Generate reports for further analysis

## Customization

### Adding New Visualizations
The app is designed to be easily extensible. To add new visualizations:

1. Add a new tab panel in the UI
2. Create corresponding server logic
3. Add database queries as needed

### Database Modifications
If you modify the database schema:

1. Update the table selection dropdowns
2. Modify the data quality checks
3. Update the visualization queries

## Troubleshooting

### Common Issues

**"Database file not found"**
- Ensure `medical_lock_hospitals.db` is in the same directory as `app.R`
- Run `python3 create_database.py` to create the database

**Package installation errors**
- Update R to the latest version
- Install packages individually if batch installation fails
- Check for system dependencies (especially on Linux)

**App won't start**
- Check that all required packages are installed
- Verify R version compatibility
- Check console for error messages

### Performance Tips

- For large datasets, consider adding pagination limits
- Use database indexes for frequently queried columns
- Implement caching for expensive operations

## Data Sources

The application works with historical data from:
- Colonial Medical Annual Lock Hospital Reports
- British India administrative records
- Military and civilian hospital operations data

## Contributing

To contribute to this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For questions or issues:
- Check the troubleshooting section above
- Review the R console for error messages
- Ensure all dependencies are properly installed

---

**Note**: This application is designed for historical research and data analysis. Always verify data accuracy and consider the historical context when interpreting results.
