# Governing Diseases and Sexuality in Colonial India
An interactive R Shiny application for exploring the Lock Hospital system in British India and Burma. This digital humanities project reconstructs how colonial medical surveillance transformed women's bodies into administrative categories through the Contagious Diseases Acts.

## About this Project

This digital humanities research infrastructure was developed to analyze the implementation of Contagious Diseases Acts in British India and Burma. The Lock Hospital system was a colonial mechanism for surveilling and controlling women, to prevent venereal disease transmission to British troops. By breaking the data down into 6 distinct digital datasets for different groups (women, men, hospitals, stations, documents and station reports), this digital project treats these materials as sets of different knowledge systems that overlap and interact with each other in complicated ways, linking up the big imperial structures that Levine writes about, the legal and gendered dimensions that Tambe explores, and the military anxieties that Wald looks at. This project brings together digital reconstruction and feminist history to show how the colonial state's methods of keeping tabs on people didn't just record how they governed sex and disease - they actually made it happen.

## The Archive

The work began with the manual extraction of tables and theoretical narrative notes from the annual lock-hospital and sanitary reports between 1870 and 1890. These reports came from six major regions: Punjab, the North-Western Provinces and Oudh, the Madras Presidency, Burma (both civil and military divisions), the Central Provinces, and the British Burma Division. Each report followed a consistent format - one section presented numbers of women registered, inspected, fined, or imprisoned; another listed venereal admissions among European and Indian troops; a third summarized committee activity and administrative remarks.

## Technical Infrastructure
Tools and Workflow
Python → R → Shiny Application

Python Workflow
Parsing: Reading CSV files, handling encoding issues and irregular delimiters
Validation: Checking duplicates, impossible values, referential integrity
Standardization: Normalizing names and categories using historical sources
Geocoding: Looking up coordinates with manual verification
Import: Writing to SQLite with schema constraints and indexes
R Workflow
Querying: Using DBI and dplyr to extract data subsets
Transformation: Calculating punishment rates, surveillance intensity, temporal trends
Visualization: Creating plots with ggplot2, interactive maps with plotly and leaflet
Application: Building Shiny dashboard with multiple analytical lenses

## Database structure:

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


## Database Schema

The application works with seven main tables:

1. **documents** - Source documents (Colonial Medical Annual Reports)
2. **stations** - 59 Lock Hospital stations with corrected geographic coordinates
3. **station_reports** - Document-station linkages
4. **women_admission** - Women's surveillance data (332 station-year records)
5. **troops** - Military venereal disease data (300 records)
6. **hospital_operations** - Legal regimes and Acts in force by station-year
7. **hospital_notes** - 362 qualitative inspection reports with textual analysis


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


## Features & Visualizations

###  Story Tab: Scrollytelling Narrative

The Story tab presents a guided narrative journey through the Lock Hospital archive, combining text, data, and visuals to contextualize the colonial medical surveillance system.

#### 1. Overview Map with Acts Filter
- **Interactive Leaflet map** showing all Lock Hospital stations across British India and Burma
- **Filterable by Contagious Diseases Acts**:
  - Act XXII of 1864 (Cantonment Act)
  - Act XIV of 1868 (Contagious Diseases Act)
  - Act III of 1880 (Cantonment Act)
  - Cantonment Act 1889
  - Voluntary System
  - No Act / Unknown
- **Geographic visualization** of how different legal regimes shaped surveillance across regions
- Hover over stations to see which Acts were in force

#### 2. Horizontal Image Gallery
- **Scrollable card gallery** in the style of the Acts timeline
- **Archive materials** including:
  - Lock Hospital exterior photographs
  - Administrative records and tables from colonial reports
  - Screenshots of original source documents
- **Click any image** to open full-resolution version in new tab
  
#### 3. Acts of Empire Timeline
- **Horizontal scrollable timeline** of three major Contagious Diseases Acts
- **Color-coded cards** for each Act with detailed context:
  - **1864 Cantonments Act XXII**: "For protection of the health of the troops" - first formal regulation of "houses of ill-fame"
  - **1868 Contagious Diseases Act XIV**: Created administrative category of "registered prostitute" with compulsory medical examination
  - **1880 Cantonment Act III**: "Voluntary" system that expanded geographic reach under guise of reform
- Explains how legal frameworks evolved and expanded state power over women's bodies

---

### Interactive Map Tab

The Interactive Map tab is the primary analytical interface, enabling year-by-year exploration of Lock Hospital operations and their relationship to colonial infrastructure.

#### 4. Main Time-Slider Map (1873-1890)
The centerpiece visualization showing Lock Hospital surveillance over time.

**Features:**
- **Year slider** with animation controls to play through 1873-1890
- **Circle markers** for each station, sized by average registered women (surveillance intensity)
- **Color-coded by region**: Burma (red), Punjab (blue), Madras (green), Bengal (orange), etc.
- **Detailed popups** on click showing:
  - Women on register (start/end of year)
  - Women admitted
  - Which Contagious Diseases Act was in force
- **Railway stations toggle** to overlay 46 railway locations
- **Interactive legend** showing regional color codes

#### 5. Lock Hospital Admission Data Table
- **Searchable DataTable** showing all station-year records for selected year
- **Sortable columns** for comparative analysis
- Complete admission flows: women registered → added → removed → end register
- Disease counts and punishment statistics
- Export-ready for statistical analysis

#### 6. Railway Stations Table
- **Collapsible table** showing 46 railway stations
- Station names and geographic coordinates
- Demonstrates colonial transportation network extent
- Can be cross-referenced with hospital locations

#### 7. Railway-Hospital Proximity Map
**Spatial analysis visualization** showing the relationship between railway infrastructure and medical surveillance sites.

## Research Questions Supported

These visualizations enable investigation of:
- Were Lock Hospitals strategically placed near railway stations and military cantonments?
- How did regional variations shape implementation?

### Temporal Questions
- When did the system reach peak intensity? (Answer: 1880-1882, 26-27 stations)
- How did surveillance change after each legal reform (1864, 1868, 1880)?
- What explains the expansion in the 1880s and decline in the late 1880s?

## Getting Started: Step-by-Step Guide

### Prerequisites

Before you begin, ensure you have the following installed on your computer:

1. **R** (version 4.0 or higher)
   - Download from: https://cran.r-project.org/
   - Choose the version for your operating system (Windows/Mac/Linux)

2. **RStudio** (recommended but optional)
   - Download from: https://posit.co/download/rstudio-desktop/
   - Provides a user-friendly interface for running R code

### Download the Project

**If you have Git installed**
```bash
# Open Terminal (Mac/Linux) or Command Prompt (Windows)
cd ~/Desktop  # or wherever you want to save the project
git clone https://github.com/meghakhanna98/medical_lock_hospitals.git
cd medical_lock_hospitals
---
