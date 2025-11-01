# Advanced Temporal-Spatial Visualization Summary

**Date:** October 28, 2025  
**Implementation:** Three new visualization tabs added to the Medical Lock Hospitals Shiny App

---

## 🎯 Research Questions Addressed

1. **How did the colonial state medicalize sexuality and transform women's bodies into administrative categories?**
2. **When and where did medicalization intensify? (temporal trends and regional geographies)**
3. **How did legal frameworks (e.g., Contagious Diseases Acts) structure surveillance and punishment?**

---

## 📊 New Visualizations Implemented

### 1. **Temporal-Spatial Correlation** Tab

**Purpose:** Reveal the relationship between military VD pressure and women's surveillance intensity.

**Components:**

#### a) Dual-Axis Time Series
- **Left Y-axis:** Surveillance Index (Women per 1,000 Troops)
- **Right Y-axis:** Troop VD Pressure (VD admissions per 1,000 Troops)
- **X-axis:** Year (1873-1890)
- **Annotations:** Vertical lines marking Act XIV (1868) and Act III (1880)
- **Insight:** Tests the military-medical nexus hypothesis—do troop VD rates correlate with women's registration?

#### b) Correlation Scatterplot
- **X-axis:** Troop VD Pressure
- **Y-axis:** Surveillance Index
- **Color:** Year gradient (temporal evolution)
- **Size:** Punishment rate
- **Insight:** Shows if high VD pressure → increased surveillance

#### c) Station × Year Heatmap
- **Rows:** Stations
- **Columns:** Years
- **Color intensity:** Surveillance Index
- **Insight:** Reveals geographic-temporal clustering of control

#### d) Regional Metrics Table
- Aggregated statistics by region:
  - Average Surveillance Index
  - Average Punishment Rate
  - Average Troop VD Pressure
  - Total Women Registered
  - Total Troops

---

### 2. **Animated Timeline** Tab

**Purpose:** Visualize the geographic spread of medicalization over time.

**Components:**

#### a) Interactive Map with Year Slider
- **Animation:** Year-by-year progression (1873-1890)
- **Circle size:** Total registered women (larger = more surveillance)
- **Circle color:** Punishment rate intensity
  - Red: High (>20%)
  - Orange: Medium (10-20%)
  - Yellow: Low (5-10%)
  - Green: Minimal (<5%)
  - Gray: No data
- **Popup info:**
  - Station name, region
  - Registered women count
  - Punishment rate
  - Surveillance index
- **Play button:** Auto-animates through years

#### b) Year-over-Year Metrics
- **Grouped bar chart** showing:
  - Total registered women
  - Total fined
  - Total imprisoned
- **Insight:** Tracks punitive action trends

---

### 3. **Disease Prevalence Map** Tab

**Purpose:** Show contagious disease distribution across stations.

**Components:**

#### a) Disease Metric Map
- **Dropdown selector** to color stations by:
  - Total Disease Cases
  - Primary Syphilis Rate
  - Secondary Syphilis Rate
  - Gonorrhoea Rate
  - Troop VD Rate
- **Color scale:** Yellow-Orange-Red (YlOrRd)
- **Popup info:** All disease metrics for each station

#### b) Disease Comparison Pie Charts
- **Left chart:** Disease distribution in **women**
  - Primary Syphilis, Secondary Syphilis, Gonorrhoea, Leucorrhoea
- **Right chart:** VD distribution in **troops**
  - Primary Syphilis, Secondary Syphilis, Gonorrhoea

---

## 🔬 Calculated Metrics (Normalized for Comparison)

### Surveillance Metrics
```
surveillance_index = (women_added + avg_registered) / troop_strength * 1000
```
**Interpretation:** Women per 1,000 troops—measures intensity of gendered surveillance relative to military presence.

### Punishment Metrics
```
punishment_rate = (fined + imprisoned × 2) / avg_registered * 100
```
**Interpretation:** Punitive actions per 100 registered women (imprisonments weighted 2× due to severity).

### Medical Categorization
```
disease_tracking_rate = total_disease_cases / avg_registered * 100
```
**Interpretation:** Disease diagnoses per 100 registered women—proxy for medicalization depth.

### Military VD Pressure
```
troop_vd_pressure = total_vd_admissions / troop_strength * 1000
```
**Interpretation:** VD cases per 1,000 troops—measures military medical need.

---

## 📈 Analytical Capabilities

### What You Can Now Explore:

1. **Causality Testing**
   - Does troop VD pressure **precede** increases in women's registration?
   - Use the dual-axis chart to identify lag patterns

2. **Act Impact Analysis**
   - Compare metrics **before/after** Act XIV (1868) and Act III (1880)
   - Vertical lines on timeline charts mark regime changes

3. **Geographic Clustering**
   - Heatmap reveals which stations intensified surveillance together
   - Animated map shows if control spread from core to periphery

4. **Disease Regimes**
   - Compare disease prevalence between women and troops
   - Test if women's disease rates mirror troop VD rates (medical justification?)

5. **Regional Heterogeneity**
   - Metrics table shows Bengal ≠ Madras ≠ Burma
   - Identify outlier stations deviating from regional patterns

---

## 🚀 How to Use

1. **Launch app:** App is now running on `http://0.0.0.0:8888`
2. **Navigate to:** Visualizations → Medicalization tab
3. **Select sub-tab:**
   - **Temporal-Spatial Correlation** for analytical depth
   - **Animated Timeline** for storytelling/presentations
   - **Disease Prevalence Map** for disease geography

---

## 🔧 Technical Implementation

### Data Processing
- **Reactive pipeline:** Merges `women_admission` + `troops` tables by year/station/region
- **Handling missing values:** `NA` for ratios with zero denominators
- **Defensive checks:** `validate(need())` prevents crashes on empty datasets

### Interactivity
- **Plotly charts:** Hover tooltips, zoom, pan
- **Leaflet maps:** Click for popups, year slider for animation
- **DT tables:** Sort, search, export

### Performance
- **Aggregation:** Pre-compute yearly/regional summaries to avoid re-calculating on every render
- **Lazy loading:** Reactives only compute when tabs are viewed

---

## 📌 Next Steps / Enhancements

### Potential Additions:

1. **Statistical Tests**
   - Add correlation coefficients to scatterplot
   - Granger causality test for VD → surveillance lag

2. **Comparative Mode**
   - Side-by-side Act XIV vs. Act III regime comparison
   - Difference maps (Act III minus Act XIV)

3. **Download Functionality**
   - Export correlation metrics CSV
   - Save animated map as GIF

4. **Ridge Plot**
   - Regional surveillance trajectories stacked as ridges
   - Clearly shows when each region peaked

5. **Network Graph**
   - Stations as nodes, edges weighted by similarity in surveillance patterns
   - Clusters reveal coordinated control zones

---

## 📚 Research Value

### Why These Methods Are Powerful:

1. **Beyond Descriptive:**
   - Not just "what happened" but **when, where, why**
   - Normalized metrics enable fair comparison across unequal units

2. **Visual Argumentation:**
   - Maps/animations are **evidence** not decoration
   - Reviewers can see patterns you describe

3. **Reproducibility:**
   - All calculations in code → transparent methods
   - Anyone can verify your metrics

4. **Publication-Ready:**
   - Plotly/Leaflet outputs export as high-res images
   - Professional aesthetics (color scales, legends, titles)

---

## 🔗 Files Modified

- **app.R:** Added 3 new tabs, correlation_data reactive, 11 new rendering outputs
- **Database:** No schema changes (read-only analysis)

---

## ✅ Testing Status

- [x] Syntax validated (`parse('app.R')` successful)
- [x] App launched on port 8888
- [ ] Visual inspection of all three tabs (awaiting user review)
- [ ] Edge case testing (no data, single year, etc.)

---

**Access the app:** Open browser to `http://localhost:8888` and navigate to **Visualizations → Medicalization → [Temporal-Spatial Correlation | Animated Timeline | Disease Prevalence Map]**
