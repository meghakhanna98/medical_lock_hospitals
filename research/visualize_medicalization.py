"""
COLONIAL MEDICALIZATION VISUALIZATIONS
Creating compelling visual narratives of how the colonial state 
transformed women's bodies into administrative categories
"""

import sqlite3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

# Set styling
sns.set_style("whitegrid")
sns.set_palette("husl")
plt.rcParams['figure.figsize'] = (16, 10)

# Connect to database
conn = sqlite3.connect('medical_lock_hospitals.db')

# Create output directory for plots
import os
os.makedirs('analysis_outputs', exist_ok=True)

print("Generating visualizations...")

# ============================================================================
# VISUALIZATION 1: Temporal Intensification of Surveillance
# ============================================================================

women = pd.read_sql_query("SELECT * FROM women_admission", conn)
ops = pd.read_sql_query("SELECT * FROM hospital_operations", conn)

# Aggregate by year
women_yearly = women.groupby('year').agg({
    'women_added': 'sum',
    'avg_registered': 'sum',
    'unique_id': 'count'
}).reset_index()

ops_yearly = ops.groupby('year').size().reset_index(name='hospital_count')

fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('Temporal Intensification of Colonial Surveillance (1873-1890)', 
             fontsize=16, fontweight='bold', y=0.995)

# Plot 1: Women Added Over Time
ax1 = axes[0, 0]
ax1.plot(women_yearly['year'], women_yearly['women_added'], 
         marker='o', linewidth=2, markersize=8, color='#e74c3c')
ax1.fill_between(women_yearly['year'], women_yearly['women_added'], 
                 alpha=0.3, color='#e74c3c')
ax1.set_title('Women Added to Registration System', fontsize=12, fontweight='bold')
ax1.set_xlabel('Year')
ax1.set_ylabel('Number of Women')
ax1.grid(True, alpha=0.3)

# Add annotation for peak
peak_year = women_yearly.loc[women_yearly['women_added'].idxmax()]
ax1.annotate(f'Peak: {int(peak_year["women_added"])} women\nin {int(peak_year["year"])}',
             xy=(peak_year['year'], peak_year['women_added']),
             xytext=(peak_year['year']-2, peak_year['women_added']*1.1),
             arrowprops=dict(arrowstyle='->', color='black', lw=1.5),
             fontsize=10, fontweight='bold')

# Plot 2: Average Registered Women
ax2 = axes[0, 1]
ax2.plot(women_yearly['year'], women_yearly['avg_registered'], 
         marker='s', linewidth=2, markersize=8, color='#3498db')
ax2.fill_between(women_yearly['year'], women_yearly['avg_registered'], 
                 alpha=0.3, color='#3498db')
ax2.set_title('Total Registered Women Under Surveillance', fontsize=12, fontweight='bold')
ax2.set_xlabel('Year')
ax2.set_ylabel('Number of Women')
ax2.grid(True, alpha=0.3)

# Plot 3: Hospital Operations Over Time
ax3 = axes[1, 0]
ax3.bar(ops_yearly['year'], ops_yearly['hospital_count'], 
        color='#2ecc71', alpha=0.7, edgecolor='black')
ax3.set_title('Lock Hospital Operations', fontsize=12, fontweight='bold')
ax3.set_xlabel('Year')
ax3.set_ylabel('Number of Hospital Operations')
ax3.grid(True, alpha=0.3, axis='y')

# Plot 4: Records Created (Bureaucratic Output)
ax4 = axes[1, 1]
ax4.plot(women_yearly['year'], women_yearly['unique_id'], 
         marker='D', linewidth=2, markersize=8, color='#9b59b6')
ax4.fill_between(women_yearly['year'], women_yearly['unique_id'], 
                 alpha=0.3, color='#9b59b6')
ax4.set_title('Bureaucratic Output: Data Records Created', 
              fontsize=12, fontweight='bold')
ax4.set_xlabel('Year')
ax4.set_ylabel('Number of Records')
ax4.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('analysis_outputs/01_temporal_surveillance.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 01_temporal_surveillance.png")

# ============================================================================
# VISUALIZATION 2: Geographic Distribution of Control
# ============================================================================

women_regional = women.groupby(['region']).agg({
    'women_added': 'sum',
    'avg_registered': 'sum',
    'unique_id': 'count'
}).reset_index().sort_values('women_added', ascending=True)

fig, axes = plt.subplots(1, 2, figsize=(16, 8))
fig.suptitle('Geography of Colonial Control', fontsize=16, fontweight='bold')

# Plot 1: Women Added by Region
ax1 = axes[0]
bars1 = ax1.barh(women_regional['region'], women_regional['women_added'], 
                 color='#e67e22', alpha=0.8, edgecolor='black')
ax1.set_title('Women Added to System by Region', fontsize=12, fontweight='bold')
ax1.set_xlabel('Number of Women')
ax1.grid(True, alpha=0.3, axis='x')

# Add value labels
for i, bar in enumerate(bars1):
    width = bar.get_width()
    ax1.text(width, bar.get_y() + bar.get_height()/2, 
             f'{int(width)}', ha='left', va='center', fontsize=9, fontweight='bold')

# Plot 2: Average Registered by Region
ax2 = axes[1]
bars2 = ax2.barh(women_regional['region'], women_regional['avg_registered'], 
                 color='#1abc9c', alpha=0.8, edgecolor='black')
ax2.set_title('Total Registered Women by Region', fontsize=12, fontweight='bold')
ax2.set_xlabel('Number of Women')
ax2.grid(True, alpha=0.3, axis='x')

# Add value labels
for i, bar in enumerate(bars2):
    width = bar.get_width()
    ax2.text(width, bar.get_y() + bar.get_height()/2, 
             f'{int(width)}', ha='left', va='center', fontsize=9, fontweight='bold')

plt.tight_layout()
plt.savefig('analysis_outputs/02_geographic_control.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 02_geographic_control.png")

# ============================================================================
# VISUALIZATION 3: Disease Categorization - The Medicalization
# ============================================================================

diseases = {
    'Primary Syphilis': women['disease_primary_syphilis'].sum(),
    'Secondary Syphilis': women['disease_secondary_syphilis'].sum(),
    'Gonorrhoea': women['disease_gonorrhoea'].sum(),
    'Leucorrhoea': women['disease_leucorrhoea'].sum()
}

fig, axes = plt.subplots(1, 2, figsize=(16, 8))
fig.suptitle('Medicalization: Disease Categories Imposed on Women\'s Bodies', 
             fontsize=16, fontweight='bold')

# Plot 1: Disease Categories (Pie Chart)
ax1 = axes[0]
colors = ['#e74c3c', '#c0392b', '#e67e22', '#f39c12']
wedges, texts, autotexts = ax1.pie(diseases.values(), labels=diseases.keys(), 
                                     autopct='%1.1f%%', startangle=90,
                                     colors=colors, explode=[0.05, 0.05, 0.05, 0.05],
                                     textprops={'fontsize': 11, 'fontweight': 'bold'})
ax1.set_title('Distribution of Disease Categories', fontsize=12, fontweight='bold')

# Plot 2: Disease Cases (Bar Chart)
ax2 = axes[1]
disease_df = pd.DataFrame(list(diseases.items()), columns=['Disease', 'Cases'])
bars = ax2.bar(disease_df['Disease'], disease_df['Cases'], 
               color=colors, alpha=0.8, edgecolor='black')
ax2.set_title('Total Cases by Disease Category', fontsize=12, fontweight='bold')
ax2.set_ylabel('Number of Cases')
ax2.tick_params(axis='x', rotation=45)
ax2.grid(True, alpha=0.3, axis='y')

# Add value labels
for bar in bars:
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height,
             f'{int(height):,}', ha='center', va='bottom', 
             fontsize=10, fontweight='bold')

plt.tight_layout()
plt.savefig('analysis_outputs/03_disease_categorization.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 03_disease_categorization.png")

# ============================================================================
# VISUALIZATION 4: Punitive Apparatus - Fines and Imprisonment
# ============================================================================

# Get yearly punishment data
punishment_yearly = women.groupby('year').agg({
    'fined_count': 'sum',
    'imprisonment_count': 'sum',
    'non_attendance_cases': 'sum'
}).reset_index()

fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('The Punitive Apparatus: Enforcement Through Legal Violence', 
             fontsize=16, fontweight='bold', y=0.995)

# Plot 1: Fines Over Time
ax1 = axes[0, 0]
ax1.plot(punishment_yearly['year'], punishment_yearly['fined_count'], 
         marker='o', linewidth=2, markersize=8, color='#e74c3c')
ax1.fill_between(punishment_yearly['year'], punishment_yearly['fined_count'], 
                 alpha=0.3, color='#e74c3c')
ax1.set_title('Women Fined for Non-Compliance', fontsize=12, fontweight='bold')
ax1.set_xlabel('Year')
ax1.set_ylabel('Number of Women Fined')
ax1.grid(True, alpha=0.3)

# Plot 2: Imprisonments Over Time
ax2 = axes[0, 1]
ax2.plot(punishment_yearly['year'], punishment_yearly['imprisonment_count'], 
         marker='s', linewidth=2, markersize=8, color='#c0392b')
ax2.fill_between(punishment_yearly['year'], punishment_yearly['imprisonment_count'], 
                 alpha=0.3, color='#c0392b')
ax2.set_title('Women Imprisoned for Non-Compliance', fontsize=12, fontweight='bold')
ax2.set_xlabel('Year')
ax2.set_ylabel('Number of Women Imprisoned')
ax2.grid(True, alpha=0.3)

# Plot 3: Non-Attendance (Resistance)
ax3 = axes[1, 0]
ax3.plot(punishment_yearly['year'], punishment_yearly['non_attendance_cases'], 
         marker='D', linewidth=2, markersize=8, color='#f39c12')
ax3.fill_between(punishment_yearly['year'], punishment_yearly['non_attendance_cases'], 
                 alpha=0.3, color='#f39c12')
ax3.set_title('Non-Attendance Cases (Potential Resistance)', 
              fontsize=12, fontweight='bold')
ax3.set_xlabel('Year')
ax3.set_ylabel('Number of Non-Attendance Cases')
ax3.grid(True, alpha=0.3)

# Plot 4: Total Punishment Summary
ax4 = axes[1, 1]
total_fines = women['fined_count'].sum()
total_imprisonment = women['imprisonment_count'].sum()
total_non_attendance = women['non_attendance_cases'].sum()

categories = ['Fines', 'Imprisonments', 'Non-Attendance\n(Resistance)']
values = [total_fines, total_imprisonment, total_non_attendance]
colors_bar = ['#e74c3c', '#c0392b', '#f39c12']

bars = ax4.bar(categories, values, color=colors_bar, alpha=0.8, edgecolor='black')
ax4.set_title('Total Punitive Actions & Resistance', fontsize=12, fontweight='bold')
ax4.set_ylabel('Count')
ax4.grid(True, alpha=0.3, axis='y')

# Add value labels
for bar in bars:
    height = bar.get_height()
    ax4.text(bar.get_x() + bar.get_width()/2., height,
             f'{int(height):,}', ha='center', va='bottom', 
             fontsize=11, fontweight='bold')

plt.tight_layout()
plt.savefig('analysis_outputs/04_punitive_apparatus.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 04_punitive_apparatus.png")

# ============================================================================
# VISUALIZATION 5: Military-Medical Nexus
# ============================================================================

troops = pd.read_sql_query("SELECT * FROM troops", conn)

# Troop disease over time
troop_yearly = troops.groupby('year').agg({
    'avg_strength': 'sum',
    'primary_syphilis': 'sum',
    'secondary_syphilis': 'sum',
    'gonorrhoea': 'sum',
    'total_admissions': 'sum'
}).reset_index()

fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('The Military-Medical Nexus: Women\'s Bodies Regulated for Military Health', 
             fontsize=16, fontweight='bold', y=0.995)

# Plot 1: Military Strength Over Time
ax1 = axes[0, 0]
ax1.plot(troop_yearly['year'], troop_yearly['avg_strength'], 
         marker='o', linewidth=2, markersize=8, color='#34495e')
ax1.fill_between(troop_yearly['year'], troop_yearly['avg_strength'], 
                 alpha=0.3, color='#34495e')
ax1.set_title('Military Troop Strength', fontsize=12, fontweight='bold')
ax1.set_xlabel('Year')
ax1.set_ylabel('Average Troop Strength')
ax1.grid(True, alpha=0.3)

# Plot 2: VD Cases in Military
ax2 = axes[0, 1]
ax2.plot(troop_yearly['year'], troop_yearly['total_admissions'], 
         marker='s', linewidth=2, markersize=8, color='#e74c3c')
ax2.fill_between(troop_yearly['year'], troop_yearly['total_admissions'], 
                 alpha=0.3, color='#e74c3c')
ax2.set_title('Venereal Disease Cases in Military', fontsize=12, fontweight='bold')
ax2.set_xlabel('Year')
ax2.set_ylabel('Total VD Admissions')
ax2.grid(True, alpha=0.3)

# Plot 3: Disease Types in Military
ax3 = axes[1, 0]
disease_types = ['Primary\nSyphilis', 'Secondary\nSyphilis', 'Gonorrhoea']
disease_totals = [
    troops['primary_syphilis'].sum(),
    troops['secondary_syphilis'].sum(),
    troops['gonorrhoea'].sum()
]
bars = ax3.bar(disease_types, disease_totals, 
               color=['#e74c3c', '#c0392b', '#e67e22'], alpha=0.8, edgecolor='black')
ax3.set_title('Military VD Cases by Type', fontsize=12, fontweight='bold')
ax3.set_ylabel('Number of Cases')
ax3.grid(True, alpha=0.3, axis='y')

for bar in bars:
    height = bar.get_height()
    if not np.isnan(height):
        ax3.text(bar.get_x() + bar.get_width()/2., height,
                 f'{int(height):,}', ha='center', va='bottom', 
                 fontsize=10, fontweight='bold')

# Plot 4: Correlation scatter
ax4 = axes[1, 1]
correlation_data = pd.read_sql_query("""
    SELECT 
        t.station,
        t.year,
        t.total_admissions as troop_disease,
        w.women_added as women_added
    FROM troops t
    LEFT JOIN women_admission w ON t.station = w.station AND t.year = w.year
    WHERE t.total_admissions IS NOT NULL AND w.women_added IS NOT NULL
""", conn)

if len(correlation_data) > 0:
    ax4.scatter(correlation_data['troop_disease'], correlation_data['women_added'],
                alpha=0.6, s=80, color='#9b59b6', edgecolor='black')
    ax4.set_title('Correlation: Military Disease & Women Surveillance', 
                  fontsize=12, fontweight='bold')
    ax4.set_xlabel('Military VD Cases')
    ax4.set_ylabel('Women Added to System')
    ax4.grid(True, alpha=0.3)
    
    # Add trend line
    if len(correlation_data) > 2:
        z = np.polyfit(correlation_data['troop_disease'], correlation_data['women_added'], 1)
        p = np.poly1d(z)
        ax4.plot(correlation_data['troop_disease'], 
                 p(correlation_data['troop_disease']), 
                 "r--", alpha=0.8, linewidth=2, label='Trend')
        ax4.legend()

plt.tight_layout()
plt.savefig('analysis_outputs/05_military_medical_nexus.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 05_military_medical_nexus.png")

# ============================================================================
# VISUALIZATION 6: The Acts - Legal Framework of Control
# ============================================================================

acts_data = pd.read_sql_query("""
    SELECT act, COUNT(*) as count 
    FROM hospital_operations 
    WHERE act IS NOT NULL AND act != 'None'
    GROUP BY act 
    ORDER BY count DESC
""", conn)

# Acts over time
acts_temporal = pd.read_sql_query("""
    SELECT year, act, COUNT(*) as count 
    FROM hospital_operations 
    WHERE act IS NOT NULL AND act != 'None'
    GROUP BY year, act
""", conn)
acts_pivot = acts_temporal.pivot(index='year', columns='act', values='count').fillna(0)

fig, axes = plt.subplots(1, 2, figsize=(16, 8))
fig.suptitle('Legal Mechanisms: Contagious Diseases Acts', 
             fontsize=16, fontweight='bold')

# Plot 1: Total Acts Usage
ax1 = axes[0]
bars = ax1.barh(acts_data['act'], acts_data['count'], 
                color='#2c3e50', alpha=0.8, edgecolor='black')
ax1.set_title('Implementation of CD Acts', fontsize=12, fontweight='bold')
ax1.set_xlabel('Number of Implementations')
ax1.grid(True, alpha=0.3, axis='x')

for i, bar in enumerate(bars):
    width = bar.get_width()
    ax1.text(width, bar.get_y() + bar.get_height()/2, 
             f'{int(width)}', ha='left', va='center', 
             fontsize=10, fontweight='bold')

# Plot 2: Acts Over Time (Stacked Area)
ax2 = axes[1]
acts_pivot.plot(kind='area', stacked=True, alpha=0.7, ax=ax2, 
                color=['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6'])
ax2.set_title('Acts Implementation Timeline', fontsize=12, fontweight='bold')
ax2.set_xlabel('Year')
ax2.set_ylabel('Number of Stations')
ax2.legend(title='Act', bbox_to_anchor=(1.05, 1), loc='upper left')
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('analysis_outputs/06_legal_framework.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 06_legal_framework.png")

# ============================================================================
# Summary Statistics Image
# ============================================================================

# Get counts for summary
stations_count = pd.read_sql_query("SELECT COUNT(*) as count FROM stations", conn)
women_records_count = pd.read_sql_query("SELECT COUNT(*) as count FROM women_admission", conn)
hospital_ops_count = pd.read_sql_query("SELECT COUNT(*) as count FROM hospital_operations", conn)
troop_records_count = pd.read_sql_query("SELECT COUNT(*) as count FROM troops", conn)

fig = plt.figure(figsize=(16, 10))
fig.suptitle('COLONIAL MEDICALIZATION: KEY STATISTICS', 
             fontsize=20, fontweight='bold', y=0.98)

# Remove axes
ax = fig.add_subplot(111)
ax.axis('off')

# Create text summary
summary_text = f"""
THE TRANSFORMATION OF WOMEN'S BODIES INTO ADMINISTRATIVE CATEGORIES
Data from British India Lock Hospitals (1873-1890)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SCALE OF SURVEILLANCE
   • {stations_count['count'][0]} Lock Hospital Stations across British India
   • {women_records_count['count'][0]} Women's Records Created
   • {hospital_ops_count['count'][0]} Hospital Operations Documented
   • {troop_records_count['count'][0]} Military Troop Records

WOMEN PROCESSED THROUGH THE SYSTEM
   • {int(women['women_added'].sum())} Women Added to Registration
   • {int(women['avg_registered'].sum())} Total Registered Women
   • {int(women['discharges'].sum())} Discharges
   • {int(women['deaths'].sum())} Deaths in System

DISEASE CATEGORIZATION
   • {int(women['disease_primary_syphilis'].sum())} Primary Syphilis Cases
   • {int(women['disease_secondary_syphilis'].sum())} Secondary Syphilis Cases
   • {int(women['disease_gonorrhoea'].sum())} Gonorrhoea Cases
   • {int(women['disease_leucorrhoea'].sum())} Leucorrhoea Cases
   • {int(women['disease_primary_syphilis'].sum() + women['disease_secondary_syphilis'].sum() + women['disease_gonorrhoea'].sum() + women['disease_leucorrhoea'].sum())} TOTAL Disease Cases Documented

PUNITIVE MEASURES
   • {int(women['fined_count'].sum())} Women Fined
   • {int(women['imprisonment_count'].sum())} Women Imprisoned
   • {int(women['non_attendance_cases'].sum())} Non-Attendance Cases (Resistance)

MILITARY RATIONALE
   • {int(troops['avg_strength'].sum())} Total Military Strength
   • {int(troops['total_admissions'].sum())} VD Cases in Military
   • Women's bodies regulated to protect military health

LEGAL FRAMEWORK
   • Contagious Diseases Acts (CD Acts) - primary mechanism
   • Act XIV of 1868, Act XXII of 1864, Act III of 1880
   • Compulsory registration, examination, and detention

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONCLUSION: This data represents the colonial state's power to transform women's
sexuality into administrative categories through medical-legal-bureaucratic means.
Each number represents a woman reduced to a data point in the imperial archive.
"""

# Station counts
stations = pd.read_sql_query("SELECT COUNT(*) as count FROM stations", conn)
women_records = pd.read_sql_query("SELECT COUNT(*) as count FROM women_admission", conn)
hospital_ops = pd.read_sql_query("SELECT COUNT(*) as count FROM hospital_operations", conn)
troop_records = pd.read_sql_query("SELECT COUNT(*) as count FROM troops", conn)

ax.text(0.5, 0.5, summary_text, 
        horizontalalignment='center',
        verticalalignment='center',
        fontsize=11,
        family='monospace',
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))

plt.tight_layout()
plt.savefig('analysis_outputs/00_summary_statistics.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 00_summary_statistics.png")

plt.close('all')

# Close connection
conn.close()

print("\n" + "="*80)
print("✅ All visualizations generated successfully!")
print("📁 Check the 'analysis_outputs' directory for all charts")
print("="*80)
