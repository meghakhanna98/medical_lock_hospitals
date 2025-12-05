# App.R Cleanup Recommendations

## Executive Summary
Your `app.R` file is **4,666 lines**. Approximately **1,500-2,000 lines (30-40%)** can be safely removed as they are:
- Unused research tabs not accessible from the UI
- Experimental/optional features (DS_Dataset)
- Duplicate code
- Commented/disabled safe_mode code

## Active Tabs (Keep These)
✅ Story  
✅ Interactive Map  
✅ Data Tables  
✅ Data Cleaning  
✅ Hospital Notes  
✅ Data Export  

## Unused Tabs (Remove Completely)
❌ q1_medicalization (~39 lines of UI + ~150 lines of server code)
❌ q2_gender (~104 lines of UI + ~200 lines of server code)
❌ q3_acts (~35 lines of UI + ~50 lines of server code)
❌ disease_analysis (~54 lines of UI + ~100 lines of server code)
❌ hospital_ops (~78 lines of UI + ~250 lines of server code)
❌ summary (~29 lines of UI + ~80 lines of server code)

**Total UI removal: ~340 lines** (lines 427-765)
**Total server removal: ~830 lines**

## Specific Removals Recommended

### 1. Remove Unused Tab UIs (Lines 427-764)
Delete entire sections for:
- `tabItem(tabName = "q1_medicalization", ...)`
- `tabItem(tabName = "q2_gender", ...)`
- `tabItem(tabName = "q3_acts", ...)`
- `tabItem(tabName = "disease_analysis", ...)`
- `tabItem(tabName = "hospital_ops", ...)`
- `tabItem(tabName = "summary", ...)`

### 2. Remove DS_Dataset Related Code (~300 lines)
This experimental feature for staff role analysis is not currently used:
- `.find_ds_dataset_file()` function
- `ds_dataset_clean()` reactive
- `ds_mentions_source()` reactive
- `ds_version` reactiveVal
- `output$ds_dataset_status`
- `output$ds_metrics_text`
- `output$ds_save_status`
- `observeEvent(input$ds_upload, ...)`
- `observeEvent(input$ds_save_to_db, ...)`
- All DS-related file upload handlers

### 3. Remove Unused Server Outputs (~400 lines)
These outputs correspond to removed tabs:
- `output$med_temporal_women_added` 
- `output$med_temporal_avg_registered`
- `output$med_temporal_ops_over_time`
- `output$med_temporal_records_created`
- `output$med_geo_women_added_by_region`
- `output$med_geo_avg_registered_by_region`
- `output$med_surveillance_sankey`
- `output$med_men_network`
- `output$med_women_network`
- `output$admissions_women_by_region`
- `output$admissions_men_by_region`
- `output$med_disease_pie`
- `output$med_disease_bar`
- `output$med_acts_total`
- `output$med_acts_timeline`
- `output$med_acts_by_station`
- `output$acts_animated_map`
- `output$acts_year_summary`
- `output$animated_timeline_map`
- `output$timeline_year_metrics`
- `output$disease_prevalence_map`
- `output$disease_comparison_women`
- `output$disease_comparison_troops`
- `output$med_summary_html`
- `output$ops_debug_info`
- `output$ops_inspection_timeline`
- `output$ops_inspection_by_region`
- `output$ops_unlicensed_methods`
- `output$ops_unlicensed_by_act`
- `output$ops_committee_distribution`
- `output$ops_committee_by_region`
- `output$ops_punishment_timeline`
- `output$ops_punishment_by_station`
- `output$ops_staff_mentions_timeline`
- `output$ops_staff_mentions_by_region`

### 4. Remove Unused Reactive Functions
- `correlation_data()` - only used by removed tabs
- `hospital_ops_enriched()` - only used by removed hospital_ops tab
- `story_terms_counts()` - word cloud feature not currently used
- `hospital_notes_df()` - needs review (may be used by hospital_notes tab)
- Helper functions: `.trim_ws()`, `.strip_specials()`, `.normalize_regularity()`, `.clean_remarks()`, `.normalize_station_key()`

### 5. Remove Safe Mode Code (~50 lines)
Lines 833-851: The SAFE_MODE toggle and all its placeholder outputs
```r
if (safe_mode) {
  message('SAFE_MODE: heavy analytics disabled...')
  # ... disabled outputs ...
}
```

### 6. Remove Duplicate Code
- `output$story_total_stats` is defined **twice** (once around line 1570, again around line 3840)
- Keep only ONE definition

### 7. Remove Unused globalVariables
Many variables in the `utils::globalVariables()` call (lines 23-30) are no longer used after removing tabs

### 8. Simplify Image Sanitization Code
The `sanitize_name()` function and image copying loop (lines 56-67) runs on every app start but could be optimized or moved to a setup script

## Estimated Final Size
**Current:** 4,666 lines  
**After cleanup:** ~2,600-2,800 lines  
**Reduction:** ~40% smaller, much easier to maintain

## Next Steps
1. **Backup first:** You've already committed, which is good
2. **Remove in order:**
   a. Unused tab UIs (lines 427-764) - safest, largest impact
   b. Corresponding server outputs
   c. DS_Dataset code
   d. Helper functions only used by removed code
   e. Safe mode code
   f. Duplicate definitions

3. **Test after each major removal** to ensure app still works

## Benefits
- Faster app loading
- Easier to maintain and debug
- Clearer code structure
- Smaller git diffs
- Better performance

Would you like me to proceed with the cleanup step-by-step?
