# Medical Lock Hospitals: Interactive Research Dashboard

A comprehensive R Shiny application for visualizing and analyzing historical data on Lock Hospitals in British India and Burma (1873-1889). This digital humanities research tool provides interactive maps and qualitative data exploration of colonial medical surveillance systems.

## Overview

This application provides an interactive interface to explore the `medical_lock_hospitals.db` SQLite database, containing digitized historical records of Lock Hospitals—institutions used to surveil and control women under the Contagious Diseases Acts. The database includes:

- **332 station-year records** across **56 unique Lock Hospital stations**
- **Women's admission data** (registration, diseases, punishments)
- **Military troop data** (venereal disease admissions)
- **Hospital operations data** (legal regimes, Acts in force)
- **362 qualitative hospital notes** (inspection reports, committee activities)
- **Geographic data** with corrected coordinates for British India and Burma

## Repository layout

To keep the Explorer uncluttered, most maintenance scripts, logs, and one-off exports have been moved into subfolders. Only what you need to run the app stays at the root.

- Root (what you need to run):
   - `app.R` – main Shiny app
   - `run_app.R` – helper launcher (optional)
   - `medical_lock_hospitals.db` – database used by the app
   - `README.md`, `content/` – documentation and images
- Archived/maintenance items:
   - `archive/exports/` – CSV exports generated previously
   - `archive/logs/` – Shiny logs
   - `archive/backups/app/` – older app files/backups
   - `archive/scripts_geocode/`, `archive/scripts_migrations/` – data maintenance scripts
   - `archive/python_tools/` – ingest/DB utilities
   - `research/` – standalone analysis notebooks/scripts


## Features

### �️ Interactive Geographic Map
- **Temporal slider**: Explore data year-by-year from 1873 to 1889
- **Geospatial visualization**: All 56 Lock Hospital stations mapped with corrected coordinates
- **Circle sizing**: Proportional to average registered women at each station
- **Color coding**: Stations colored by region (Burma, Punjab, Madras, Bengal, etc.)
- **Interactive popups**: Click stations to see detailed admission data
- **Data filtering**: Map shows only stations with actual women's data for selected year
- **Smart display**: Decimal formatting removed for cleaner presentation

### � Hospital Notes Page
- **Qualitative data explorer**: Browse all 362 hospital inspection notes
- **Rich textual data**: Inspection regularity, unlicensed women control, committee activities, remarks
- **Searchable interface**: Filter by station, year, region, or keywords
- **Document linkage**: Each note linked to source documents
- **Year extraction**: Automatic parsing of years from document IDs
- **Text normalization**: Cleaned and standardized note content

### 📋 Lock Hospital Admissions Table
- **Women's surveillance data**: Registration, additions, removals by station and year
- **Disease tracking**: Primary syphilis, secondary syphilis, gonorrhoea, leucorrhoea
- **Punishment records**: Fines and imprisonments for non-compliance
- **Filtered display**: Shows only stations with actual data (no empty rows)
- **Whole number formatting**: Clean integer display for counts
- **Export capability**: Download filtered data for analysis


## Database Schema

The application works with seven main tables:

1. **documents** - Source documents (Colonial Medical Annual Reports)
2. **stations** - 59 Lock Hospital stations with corrected geographic coordinates
3. **station_reports** - Document-station linkages
4. **women_admission** - Women's surveillance data (332 station-year records)
5. **troops** - Military venereal disease data (300 records)
6. **hospital_operations** - Legal regimes and Acts in force by station-year
7. **hospital_notes** - 362 qualitative inspection reports with textual analysis

### Data Coverage Summary

- **Temporal range**: 1873-1889 (17 years)
- **Geographic scope**: 56 unique Lock Hospital stations across British India and Burma
- **Peak surveillance**: 1880-1882 (26-27 stations reporting)
- **Initial deployment**: 1873 (6 Burma stations: Rangoon, Moulmein, Bassein, Tonghoo, Thayetmyo, Mandalay)
- **Regional distribution**: Burma, Punjab, Madras, Bengal, Bombay, Central India, Northwestern Provinces

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


**Geographic coordinate fixes:**
- **Moulmein**: Corrected from Mumbai (18.98°, 72.83°) to Burma (16.49°, 97.63°)
- **Bassein**: Corrected from Mumbai/Vasai (19.38°, 72.83°) to Pathein, Burma (16.78°, 94.73°)
- **Peshawar**: Corrected from Hyderabad (17.40°, 78.46°) to Pakistan/Punjab frontier (34.02°, 71.52°)
- **Nagpur and Kamptee**: Coordinates verified as correct in Central India

**Station name standardization:**
- "Sitabaldi" and "Seetabuldee" unified to "Nagpur" with proper coordinates
- "India (British Burma)" consolidated to "Rangoon" (standardized in October 2025)

**Display improvements:**
- Removed decimal formatting from whole number counts (e.g., 119.0 → 119)
- Filtered empty data rows (showing only stations with actual women's data)
- Default year set to 1873 (earliest data point) instead of 1879

All changes are backed up in archive/backups/ and reflected in the live SQLite database.

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
- R (version 4.0 or higher recommended)
- RStudio (recommended for development)
- The `medical_lock_hospitals.db` SQLite database file (included in repository)

### Quick Start

1. **Clone or download this repository**

2. **Install R packages**:
   ```bash
   Rscript install_packages.R
   ```

3. **Run the application**:
   ```bash
   Rscript run_app.R
   ```
   
   Or from R console:
   ```r
   source("run_app.R")
   ```

4. **Access the app**: Open your web browser to `http://127.0.0.1:8891`

The app will launch in SAFE_MODE by default, which prevents accidental data modifications.

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

### Interactive Map Tab (Primary Interface)
1. **Use the year slider** to navigate from 1873 to 1889
2. **Hover over circles** to see station names and regions
3. **Click on stations** to view detailed popup with:
   - Total registered women
   - Women added/removed
   - Disease statistics (syphilis, gonorrhoea, leucorrhoea)
   - Punishment data (fines, imprisonments)
4. **Circle size** represents average registered women
5. **Color** indicates geographic region

### Hospital Notes Tab
1. **Browse qualitative data** from 362 inspection reports
2. **Search and filter** by station, year, or keywords
3. **Read detailed notes** on:
   - Inspection regularity (weekly, monthly, irregular)
   - Control of unlicensed women
   - Committee and magistrate oversight
   - General remarks from colonial officials
4. **Export filtered notes** for textual analysis

### Lock Hospital Admissions Table
1. **View tabular data** for all station-year records
2. **Filter and search** to find specific stations or years
3. **See complete admission flows**: start register → additions → removals → end register
4. **Track disease patterns** across time and space
5. **Export data** in CSV format for statistical analysis

### Understanding the Data
- **avg_registered**: Monthly average of women under surveillance
- **women_added**: New women registered during the year
- **women_removed**: Women released/removed from register
- **fined_count** and **imprisonment_count**: Coercive enforcement measures
- **disease counts**: Medical surveillance outcomes

## Research Applications

This dashboard supports multiple types of historical analysis:

### Spatial Analysis
- Map the geographic expansion of Lock Hospital surveillance (1873-1889)
- Compare regional implementation patterns (Burma vs. Punjab vs. Madras)
- Analyze proximity to military cantonments and railway infrastructure

### Temporal Analysis
- Track the growth and decline of the Lock Hospital system
- Correlate with legal regime changes (Acts of 1864, 1868, 1880)
- Identify periods of intensified or relaxed surveillance

### Quantitative Analysis
- Women's registration numbers as proxy for surveillance intensity
- Disease statistics and medical categorization practices
- Punishment data (fines/imprisonments) as measure of coercive enforcement
- Troop-to-women ratios for military-medical nexus analysis

### Qualitative Analysis
- Inspection reports reveal colonial administrative practices
- Committee notes show local resistance and negotiation
- Remarks provide narrative context for quantitative patterns
- Document diverse regional implementations of imperial policy

### Data Export for Advanced Analysis
- Export to CSV for statistical software (R, Python, STATA)
- Geographic coordinates ready for GIS analysis (QGIS, ArcGIS)
- Temporal data structured for time-series analysis
- Textual notes prepared for computational text analysis

## Technical Details

### Key Technologies
- **R Shiny**: Interactive web application framework
- **Leaflet**: Interactive mapping with OpenStreetMap
- **DT**: Interactive data tables
- **RSQLite**: Database connectivity
- **dplyr**: Data manipulation
- **stringr**: Text processing for qualitative notes

### Application Architecture
- **Reactive programming**: Efficient data updates based on user input
- **SAFE_MODE**: Prevents accidental data modifications
- **Database connections**: Connection pooling for performance
- **Text normalization**: Automated cleaning of qualitative notes
- **Dynamic filtering**: Real-time data filtering based on year selection

### Data Integrity
- **Coordinate validation**: All geographic coordinates verified against historical sources
- **Foreign key constraints**: Maintain referential integrity across tables
- **Backup system**: All modifications backed up to `archive/backups/`
- **Version control**: Database changes tracked with timestamps

## Troubleshooting

### Common Issues

**"Database file not found"**
- Ensure `medical_lock_hospitals.db` is in the same directory as `app.R`
- Database should be 5-10 MB in size (check file exists and isn't corrupted)

**Package installation errors**
- Update R to version 4.0 or higher: `install.packages("installr"); installr::updateR()`
- Install packages individually if batch fails: `install.packages("shiny")`
- macOS users may need XQuartz for some dependencies

**App shows no data on map**
- Check year slider is set to a year with data (1873-1889)
- Verify database has not been corrupted (332 records in women_admission)
- Check browser console for JavaScript errors

**Port already in use (8891)**
- Kill existing R sessions: `pkill -f run_app.R`
- Or use different port in run_app.R

### Performance Notes
- Initial load indexes 59 stations and calculates 332 station-year records
- Map rendering is optimized to show only stations with data
- Large text exports may take 2-3 seconds (362 hospital notes)

## Data Sources & Provenance

### Primary Sources
- **Colonial Medical Annual Lock Hospital Reports** (1873-1889)
- **Report on the Contagious Diseases Acts** (various years)
- **Annual Sanitary Reports**: British India, Burma, Bengal, Madras, Bombay, Punjab
- **Parliamentary Papers**: Reports on the operation of Contagious Diseases Acts in India

### Digitization Process
1. Historical documents digitized from archives
2. Data extracted via Python tools (`python_tools/extract_burma_women_data.py`)
3. Station coordinates geocoded and manually verified
4. Text notes cleaned and standardized
5. Database created with referential integrity constraints

### Data Quality
- **Geographic accuracy**: All station coordinates manually verified against historical maps
- **Temporal completeness**: 17 consecutive years of data (1873-1889)
- **Source linkage**: All records linked to original documents via `doc_id`
- **Qualitative preservation**: 362 original inspection notes preserved with minimal cleaning

## Project Context

This digital humanities research infrastructure was developed to analyze the implementation of Contagious Diseases Acts in British India and Burma. The Lock Hospital system was a colonial mechanism for surveilling and controlling women, ostensibly to prevent venereal disease transmission to British troops.

### Research Questions Supported
- How did Lock Hospital surveillance expand geographically over time?
- What were regional variations in implementation intensity?
- How did legal regimes (different Acts) shape surveillance practices?
- What do punishment records reveal about resistance and enforcement?
- How did colonial officials describe and justify these practices?

### Scholarly Significance
This dashboard makes visible the bureaucratic infrastructure of colonial medical surveillance, connecting quantitative patterns (women registered, diseases recorded, punishments imposed) with qualitative evidence (inspection reports, official remarks). It supports both macroscopic analysis (trends across time and space) and microscopic examination (individual station practices).

## Citation

If you use this dashboard or data in your research, please cite:

```
Medical Lock Hospitals Interactive Research Dashboard (2025)
Digital Humanities Research Tool for Colonial Medical Surveillance in British India and Burma, 1873-1889
https://github.com/meghakhanna98/medical_lock_hospitals
```

## Acknowledgments

- Historical archives for document preservation and access
- OpenStreetMap contributors for base map tiles
- R Shiny and Leaflet development communities

## License

This project is open source and available under the MIT License. Historical data is in the public domain.

---

**Research Ethics Note**: This database documents a coercive colonial system that caused significant harm to women. The data should be used to understand and critique colonial medical surveillance, not to perpetuate harmful categorizations. Station names, coordinates, and statistics are preserved for historical accuracy, but we acknowledge the violence embedded in this archive.
