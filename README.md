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

## Data Dictionary and Glossary

This section defines tables, columns, and key terms to help you navigate and interpret the dataset. Column types reflect their representation in the SQLite database; R and Python may coerce types at runtime.

### Tables and Columns

- documents
   - doc_id (TEXT): Stable document identifier (primary key, unique)
   - source_name (TEXT): Human-readable title of the document/report
   - type (TEXT): Document type (e.g., Colonial Medical Annual Lock Hospital Report)
   - link (TEXT): URL to digital copy where available
   - notes (TEXT): Free-form notes/annotations

- stations
   - station_id (INTEGER): Station identifier (primary key)
   - name (TEXT): Canonical station name
   - region (TEXT): Administrative region/presidency (historical)
   - country (TEXT): High-level political unit (e.g., British India, British Burma)
   - latitude (REAL): Decimal degrees latitude (WGS84)
   - longitude (REAL): Decimal degrees longitude (WGS84)
   - notes (TEXT): Free-form notes

- station_reports
   - report_id (INTEGER): Link row identifier (primary key)
   - doc_id (TEXT): Foreign key → documents.doc_id
   - station_id (INTEGER): Foreign key → stations.station_id

- hospital_operations
   - hid (TEXT): Operation/hospital record id (primary key, unique within table)
   - doc_id (TEXT): Foreign key → documents.doc_id
   - year (INT): Report year (Gregorian)
   - region (TEXT): Region corresponding to the hospital entry
   - station (TEXT): Station name (text join to stations.name)
   - country (TEXT): Country/political unit at the time
   - act (TEXT): Legal regime in force (e.g., Act XXII of 1864, Act XIV of 1868, Act III of 1880, Voluntary System)
   - class (TEXT): Subclassification where present

- hospital_notes
   - hid (TEXT): Foreign key → hospital_operations.hid
   - doc_id (TEXT): Foreign key → documents.doc_id
   - ops_inspection_regularity (TEXT): Narrative quality of inspection frequency
   - ops_unlicensed_control_notes (TEXT): Narrative on control of unlicensed women
   - ops_committee_activity_notes (TEXT): Narrative on committee/oversight
   - remarks (TEXT): General remarks from the report (free text)
   - inspection_freq (TEXT): Normalized inspection frequency (e.g., weekly, monthly, irregular)
   - unlicensed_control_type (TEXT): Normalized control types (e.g., police_action, special_constables, other)
   - committee_supervision (TEXT): Normalized committee oversight (e.g., magistrate_oversight, committee, subcommittee_regular)
   - extracted_year (INTEGER): Parsed year if present in remarks
   - extracted_patient_count (INTEGER): Parsed patient counts from text where available

- women_admission
   - unique_id (TEXT): Row identifier (primary key within the table)
   - doc_id (TEXT): Foreign key → documents.doc_id
   - source_name (TEXT): Document title (redundant convenience)
   - source_type (TEXT): Document type (redundant convenience)
   - region (TEXT): Administrative region
   - station (TEXT): Station name (text join to stations.name)
   - country (TEXT): Country/political unit
   - year (REAL): Year of report (coerce to INT for analysis)
   - women_start_register (REAL): Women carried forward at start of period
   - women_added (REAL): Women newly added/registered during period
   - women_removed (REAL): Women removed/deregistered during period
   - women_end_register (REAL): Women on register at end of period
   - avg_registered (REAL): Average registered women (often monthly average summed across months in source)
   - non_attendance_cases (REAL): Recorded instances of non-attendance for inspection/treatment
   - fined_count (REAL): Number of women fined for non-compliance
   - imprisonment_count (REAL): Number of women imprisoned for non-compliance
   - disease_primary_syphilis (REAL): Recorded primary syphilis cases among women
   - disease_secondary_syphilis (REAL): Recorded secondary syphilis cases among women
   - disease_gonorrhoea (REAL): Recorded gonorrhoea cases among women
   - disease_leucorrhoea (REAL): Recorded leucorrhoea cases among women
   - discharges (REAL): Women discharged
   - deaths (REAL): Recorded deaths among registered women
   - Total (REAL): Source total (when present)
   - side_notes (TEXT): Free-form notes tied to row

- women_data
   - Same semantic meaning as women_admission but a narrower subset of columns for some sources; use women_admission for the full series.

- troops
   - unique_id (TEXT): Row id (primary key within table)
   - doc_id (TEXT): Foreign key → documents.doc_id
   - source_name (TEXT), source_type (TEXT): Redundant convenience fields
   - region (TEXT), station (TEXT), country (TEXT)
   - year (REAL): Year (coerce to INT for analysis)
   - Regiments (TEXT): Unit names present at station
   - avg_strength (REAL): Average troop strength in period
   - primary_syphilis (REAL): VD admissions: primary syphilis
   - secondary_syphilis (REAL): VD admissions: secondary syphilis
   - gonorrhoea (REAL): VD admissions: gonorrhoea
   - orchitis_gonorrhoea (REAL), phimosis (REAL), warts (REAL): Additional recorded conditions
   - total_admissions (REAL): Total VD admissions among troops
   - contracted_elsewhere (REAL), contracted_at_station (REAL): Provenance where recorded
   - ratio_per_1000 (TEXT): Rate per 1,000 (keep as text due to inconsistent formatting in sources)
   - period_of_occupation (TEXT): Narrative (e.g., “Whole year”)

- troop_data
   - Earlier/alternate ingest of troop metrics; schema mirrors troops but may have small naming differences; prefer troops for complete fields.

### Keys and Joins

- documents joined by doc_id to: hospital_operations, hospital_notes, women_admission, troops, station_reports
- stations joined by station_id to: station_reports; joined by name (TEXT) to: hospital_operations, women_admission, troops
- hospital_operations joined to hospital_notes by hid

Tip: Prefer station_id joins via station_reports for document-station relationships when possible; name-based joins are convenient but sensitive to spelling.

### Controlled Vocabularies and Values

- act (hospital_operations.act)
   - Act XXII of 1864, Act XIV of 1868, Act III of 1880, Act XII of 1864, Voluntary System
- inspection_freq (hospital_notes)
   - weekly, monthly, fortnightly, daily, regular, irregular
- unlicensed_control_type (hospital_notes)
   - police_action, special_constables, other
- committee_supervision (hospital_notes)
   - magistrate_oversight, committee, subcommittee_regular, subcommittee_irregular

### Standardizations and Naming Rules (Applied in October 2025)

- “India (British Burma)” and “India (British Burma)+G143” → standardized to Rangoon
   - Duplicated station rows consolidated into a single canonical “Rangoon”; dependent rows in station_reports repointed
- “Seetabuldee” and “Sitabaldi” unified to “Sitabaldi (Nagpur)” with coordinates set
- Coordinates added/updated (WGS84) for: Tonghoo (18.9398, 96.4344), Jubbulpore (23.1686, 79.9339), Muttra (27.4924, 77.6737), Umballa (30.3752, 76.7821), Meean Meer (31.5484, 74.3602), Fyzabad (26.7730, 82.1458), Mooltan (30.1979793, 71.4724978)

All changes were scripted with backups to archive/backups/ and are reflected in the live SQLite database.

### Geospatial Conventions

- Coordinates: decimal degrees, WGS84
- Missing coordinates are left NULL (NA in R)
- When multiple historical spellings exist, we standardize to one canonical station name and preserve the mapping in ingest scripts

### Interpretation Notes

- “avg_registered” in women_admission is a source-derived average (often monthly) and may be used as a proxy for surveillance intensity; it is not an instantaneous headcount
- “non_attendance_cases”, “fined_count”, and “imprisonment_count” document the coercive apparatus around registration and inspection
- Troop disease measures and women registration flows can be compared at the station-year level to analyze the military-medical nexus

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
