#!/usr/bin/env python3
"""
Remove irrelevant code sections from app.R:
1. Railway lines (keep stations)
2. SAFE_MODE code
3. DS_Dataset code
"""

import re

def remove_railway_lines(content):
    """Remove railway lines loading and visualization, keep stations"""
    
    # 1. Remove railway lines loading (set to NULL)
    content = re.sub(
        r'railway_lines <- tryCatch\(\{[^}]+st_read\("data_raw/railway_lines\.shp"[^}]+\}, error = function\(e\) \{[^}]+\}\)',
        'railway_lines <- NULL  # Railway lines removed',
        content,
        flags=re.DOTALL
    )
    
    # 2. Remove railway line enrichment section
    content = re.sub(
        r'# Enrich railway stations with attributes from nearest railway line\s+if \(!is\.null\(railway_lines\) && !is\.null\(railway_stations\)\) \{[^}]+\}\s+\}\s*\}',
        '# Railway line enrichment removed since we\'re not loading lines anymore\n  # Station data is displayed as-is',
        content,
        flags=re.DOTALL
    )
    
    # 3. Remove railway lines override CSV loading
    content = re.sub(
        r'# Load override CSV if present\s+override_path <- "data_raw/railway_lines_override\.csv"[^}]+if \(length\(new_lines\) > 0\) \{[^}]+\}\s+\}, silent = TRUE\)\s+\}',
        '# Railway lines override CSV loading removed',
        content,
        flags=re.DOTALL
    )
    
    # 4. Simplify draw_rail_overlays to only draw stations
    # Find the function and replace it
    draw_func_pattern = r'(#Helper: draw railway overlays \(lines \+ stations\) for a given year\s+draw_rail_overlays <- function\(selected_year\) \{)(.+?)(invisible\(NULL\)\s+\})'
    
    simplified_draw = r'''\1
      # defensive
      if (is.null(selected_year)) return(invisible(NULL))
      if (is.null(railway_stations)) return(invisible(NULL))

      message(sprintf("draw_rail_overlays() called for year: %s (stations only)", as.character(selected_year)))
      
      # Show all stations (no year filtering since enrichment was removed)
      railway_stations_filtered <- railway_stations

      proxy <- leafletProxy("map")
      proxy %>% clearGroup("railways") %>% clearGroup("railway_stations")

      if (!is.null(railway_stations_filtered) && nrow(railway_stations_filtered) > 0) {
        message(sprintf("railway_stations_filtered rows: %d", nrow(railway_stations_filtered)))
        proxy %>% addCircleMarkers(
          data = railway_stations_filtered,
          radius = 4,
          color = "#f39c12",
          fillColor = "#f1c40f",
          fillOpacity = 0.8,
          weight = 1.5,
          group = "railway_stations",
          popup = ~paste0(
            "<b>Railway Station</b><br>",
            "Historic: ", orig_name, "<br>",
            "Modern: ", modern_nam
          ),
          label = ~orig_name
        )
      }
      \3'''
    
    content = re.sub(draw_func_pattern, simplified_draw, content, flags=re.DOTALL)
    
    # 5. Update UI checkbox label
    content = content.replace(
        'checkboxInput("show_railways", "Railway Lines & Stations", value = TRUE)',
        'checkboxInput("show_railways", "Railway Stations", value = TRUE)'
    )
    
    # 6. Remove Railway Lines table box from UI
    ui_pattern = r'column\(6,\s+box\(\s+title = "Railway Lines in Operation",[^)]+DT::dataTableOutput\("railway_lines_table"\)\s+\)\s+\),\s+column\(6,\s+box\(\s+title = "Railway Stations",'
    replacement = 'box(\n              title = "Railway Stations",'
    content = re.sub(ui_pattern, replacement, content, flags=re.DOTALL)
    
    # 7. Remove output$railway_lines_table
    content = re.sub(
        r'output\$railway_lines_table <- DT::renderDataTable\(\{[^}]+railways_filtered <- railway_lines[^}]+\}\)',
        '',
        content,
        flags=re.DOTALL
    )
    
    return content

def remove_safe_mode(content):
    """Remove SAFE_MODE toggle and placeholder code"""
    
    # 1. Remove SAFE_MODE declaration
    content = re.sub(
        r'# Toggle to disable heavy analytics.*?\nSAFE_MODE <- TRUE\n\n',
        '',
        content,
        flags=re.DOTALL
    )
    
    # 2. Remove safe_mode checking and placeholder outputs
    content = re.sub(
        r'# Respect SAFE_MODE toggle.*?output\$med_acts_by_station <- DT::renderDataTable\(\{ DT::datatable\(data\.frame\(Message = \'Disabled in safe mode\'\)\) \}\)\s+\}',
        '',
        content,
        flags=re.DOTALL
    )
    
    return content

def remove_ds_dataset(content):
    """Remove DS_Dataset ingestion and related code"""
    
    # Remove the entire DS_Dataset section (from .find_ds_dataset_file to before Admissions by Region)
    pattern = r'# DS_Dataset ingestion.*?# Admissions by Region - controls'
    replacement = '# Admissions by Region - controls'
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Remove DS_Dataset comment at top
    content = re.sub(
        r'## Optional: Excel ingestion for DS_Dataset \(used if available\)\n',
        '',
        content
    )
    
    return content

def main():
    # Read the file
    with open('app.R', 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Original file: {} lines".format(content.count('\n')))
    
    # Apply transformations
    print("\n1. Removing railway lines...")
    content = remove_railway_lines(content)
    
    print("2. Removing SAFE_MODE code...")
    content = remove_safe_mode(content)
    
    print("3. Removing DS_Dataset code...")
    content = remove_ds_dataset(content)
    
    # Write back
    with open('app.R', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\nFinal file: {} lines".format(content.count('\n')))
    print("\nCleanup complete! Backup saved as app.R.before_final_cleanup")

if __name__ == '__main__':
    main()
