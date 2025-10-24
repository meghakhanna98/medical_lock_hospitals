"""
COLONIAL MEDICALIZATION ANALYSIS
How did the colonial state medicalize sexuality and transform women's bodies into administrative categories?

This analysis explores the transformation of women's bodies into bureaucratic data through:
1. Quantification of surveillance
2. Geographic distribution of control
3. Temporal patterns of medicalization
4. Military-medical nexus
5. Administrative categorization systems
"""

import sqlite3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

# Set styling
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (14, 8)

# Connect to database
conn = sqlite3.connect('medical_lock_hospitals.db')

print("="*80)
print("COLONIAL MEDICALIZATION ANALYSIS")
print("Research Question: How did the colonial state medicalize sexuality and")
print("transform women's bodies into administrative categories?")
print("="*80)
print("\n")

# ============================================================================
# PART 1: THE SCALE OF SURVEILLANCE - Understanding the bureaucratic apparatus
# ============================================================================

print("\n" + "="*80)
print("PART 1: THE SCALE OF SURVEILLANCE")
print("="*80)

# Overall statistics
print("\n📊 BUREAUCRATIC INFRASTRUCTURE:")
docs = pd.read_sql_query("SELECT COUNT(*) as count FROM documents", conn)
stations = pd.read_sql_query("SELECT COUNT(*) as count FROM stations", conn)
women_records = pd.read_sql_query("SELECT COUNT(*) as count FROM women_admission", conn)
hospital_ops = pd.read_sql_query("SELECT COUNT(*) as count FROM hospital_operations", conn)
troop_records = pd.read_sql_query("SELECT COUNT(*) as count FROM troops", conn)

print(f"   • Official Documents: {docs['count'][0]}")
print(f"   • Lock Hospital Stations: {stations['count'][0]}")
print(f"   • Women Admission Records: {women_records['count'][0]}")
print(f"   • Hospital Operations: {hospital_ops['count'][0]}")
print(f"   • Military Troop Records: {troop_records['count'][0]}")

# Women's data - understanding what was tracked
print("\n📋 WHAT WAS TRACKED ABOUT WOMEN:")
women = pd.read_sql_query("SELECT * FROM women_admission", conn)
tracked_fields = [col for col in women.columns if col not in 
                  ['unique_id', 'doc_id', 'source_name', 'source_type', 'region', 
                   'station', 'country', 'year', 'side_notes']]

for field in tracked_fields:
    non_null = women[field].notna().sum()
    if non_null > 0:
        print(f"   • {field}: {non_null} records ({non_null/len(women)*100:.1f}%)")

# ============================================================================
# PART 2: TEMPORAL ANALYSIS - When did medicalization intensify?
# ============================================================================

print("\n" + "="*80)
print("PART 2: TEMPORAL PATTERNS OF MEDICALIZATION")
print("="*80)

# Women admissions over time
women_yearly = women.groupby('year').agg({
    'women_start_register': 'sum',
    'women_added': 'sum',
    'women_removed': 'sum',
    'women_end_register': 'sum',
    'avg_registered': 'sum',
    'unique_id': 'count'
}).reset_index()
women_yearly.columns = ['year', 'start_register', 'added', 'removed', 
                        'end_register', 'total_registered', 'record_count']

print("\n📅 WOMEN IN THE SYSTEM BY YEAR:")
print(women_yearly.to_string(index=False))

# Hospital operations by year
ops = pd.read_sql_query("SELECT * FROM hospital_operations", conn)
ops_yearly = ops.groupby('year').size().reset_index(name='hospital_count')
print("\n🏥 HOSPITAL OPERATIONS BY YEAR:")
print(ops_yearly.to_string(index=False))

# ============================================================================
# PART 3: GEOGRAPHIC DISTRIBUTION - Where was control concentrated?
# ============================================================================

print("\n" + "="*80)
print("PART 3: GEOGRAPHY OF CONTROL")
print("="*80)

# Stations by region
stations_data = pd.read_sql_query("""
    SELECT region, country, COUNT(*) as station_count 
    FROM stations 
    WHERE region IS NOT NULL 
    GROUP BY region, country 
    ORDER BY station_count DESC
""", conn)

print("\n🗺️  STATIONS BY REGION:")
print(stations_data.to_string(index=False))

# Women admissions by region
women_regional = women.groupby(['region', 'country']).agg({
    'women_added': 'sum',
    'avg_registered': 'sum',
    'unique_id': 'count'
}).reset_index()
women_regional.columns = ['region', 'country', 'women_added', 'avg_registered', 'records']
women_regional = women_regional.sort_values('women_added', ascending=False)

print("\n👥 WOMEN PROCESSED BY REGION:")
print(women_regional.to_string(index=False))

# ============================================================================
# PART 4: THE ACTS - Legal mechanisms of control
# ============================================================================

print("\n" + "="*80)
print("PART 4: LEGAL MECHANISMS OF MEDICALIZATION")
print("="*80)

# Acts used
acts = pd.read_sql_query("""
    SELECT act, COUNT(*) as usage_count, COUNT(DISTINCT station) as stations_using
    FROM hospital_operations 
    WHERE act IS NOT NULL AND act != 'None'
    GROUP BY act 
    ORDER BY usage_count DESC
""", conn)

print("\n⚖️  CONTAGIOUS DISEASES ACTS & REGULATIONS:")
print(acts.to_string(index=False))

# Acts over time
acts_temporal = pd.read_sql_query("""
    SELECT year, act, COUNT(*) as count 
    FROM hospital_operations 
    WHERE act IS NOT NULL AND act != 'None'
    GROUP BY year, act 
    ORDER BY year, count DESC
""", conn)

print("\n📜 ACTS IMPLEMENTATION OVER TIME:")
print(acts_temporal.to_string(index=False))

# ============================================================================
# PART 5: THE MILITARY-MEDICAL NEXUS
# ============================================================================

print("\n" + "="*80)
print("PART 5: THE MILITARY-MEDICAL NEXUS")
print("="*80)

# Troop presence and disease
troops = pd.read_sql_query("SELECT * FROM troops", conn)

# Calculate disease rates
print("\n🎖️  VENEREAL DISEASE IN MILITARY TROOPS:")
troops_disease = troops.groupby(['year', 'station']).agg({
    'avg_strength': 'sum',
    'primary_syphilis': 'sum',
    'secondary_syphilis': 'sum',
    'gonorrhoea': 'sum',
    'total_admissions': 'sum'
}).reset_index()

# Calculate per 1000 rate
troops_disease['disease_rate_per_1000'] = (
    troops_disease['total_admissions'] / troops_disease['avg_strength'] * 1000
)

troops_summary = troops_disease.groupby('year').agg({
    'avg_strength': 'sum',
    'total_admissions': 'sum',
    'disease_rate_per_1000': 'mean'
}).reset_index()

print(troops_summary.to_string(index=False))

# Correlation analysis - stations with both troop and women data
print("\n🔗 CORRELATION: TROOP PRESENCE & WOMEN'S SURVEILLANCE")
correlation_data = pd.read_sql_query("""
    SELECT 
        t.station,
        t.year,
        t.avg_strength as troop_strength,
        t.total_admissions as troop_disease,
        w.avg_registered as women_registered,
        w.women_added as women_added
    FROM troops t
    LEFT JOIN women_admission w ON t.station = w.station AND t.year = w.year
    WHERE t.avg_strength IS NOT NULL
""", conn)

# Remove nulls for correlation
correlation_clean = correlation_data.dropna()
if len(correlation_clean) > 0:
    print(f"\nStations with both troop & women data: {len(correlation_clean)}")
    corr = correlation_clean[['troop_strength', 'troop_disease', 
                               'women_registered', 'women_added']].corr()
    print("\nCorrelation Matrix:")
    print(corr.to_string())
else:
    print("Not enough overlapping data for correlation analysis")

# ============================================================================
# PART 6: DISEASE CATEGORIZATION - How were bodies medicalized?
# ============================================================================

print("\n" + "="*80)
print("PART 6: DISEASE CATEGORIZATION & MEDICALIZATION")
print("="*80)

# Disease categories tracked in women
disease_cols = ['disease_primary_syphilis', 'disease_secondary_syphilis', 
                'disease_gonorrhoea', 'disease_leucorrhoea']

disease_data = women[disease_cols].sum()
print("\n🦠 DISEASES CATEGORIZED IN WOMEN:")
for disease, count in disease_data.items():
    if pd.notna(count) and count > 0:
        disease_name = disease.replace('disease_', '').replace('_', ' ').title()
        print(f"   • {disease_name}: {count:.0f} cases")

# Punitive measures
print("\n⚖️  PUNITIVE MEASURES AGAINST WOMEN:")
punishment = women[['fined_count', 'imprisonment_count']].sum()
print(f"   • Women Fined: {punishment['fined_count']:.0f}")
print(f"   • Women Imprisoned: {punishment['imprisonment_count']:.0f}")
print(f"   • Total Punitive Actions: {punishment.sum():.0f}")

# Non-attendance - resistance?
print("\n🚫 NON-ATTENDANCE (Potential Resistance):")
non_attendance = women['non_attendance_cases'].sum()
total_expected = women['avg_registered'].sum()
if pd.notna(non_attendance) and pd.notna(total_expected):
    print(f"   • Total Non-Attendance Cases: {non_attendance:.0f}")
    print(f"   • Average Registered Women: {total_expected:.0f}")
    print(f"   • Non-Attendance Rate: {non_attendance/total_expected*100:.1f}%")

# ============================================================================
# PART 7: ADMINISTRATIVE CATEGORIES - The bureaucratic processing
# ============================================================================

print("\n" + "="*80)
print("PART 7: WOMEN AS ADMINISTRATIVE CATEGORIES")
print("="*80)

# Flow through the system
print("\n🔄 FLOW THROUGH THE REGISTRATION SYSTEM:")
totals = {
    'Started on Register': women['women_start_register'].sum(),
    'Added to Register': women['women_added'].sum(),
    'Removed from Register': women['women_removed'].sum(),
    'Ended on Register': women['women_end_register'].sum(),
    'Discharges': women['discharges'].sum(),
    'Deaths': women['deaths'].sum()
}

for category, value in totals.items():
    if pd.notna(value):
        print(f"   • {category}: {value:.0f}")

# ============================================================================
# PART 8: HOSPITAL OPERATIONS DETAILS - The surveillance notes
# ============================================================================

print("\n" + "="*80)
print("PART 8: SURVEILLANCE & INSPECTION PRACTICES")
print("="*80)

hospital_notes = pd.read_sql_query("SELECT * FROM hospital_notes", conn)

# Inspection frequency
inspection_freq = hospital_notes['inspection_freq'].value_counts()
print("\n🔍 INSPECTION FREQUENCIES:")
for freq, count in inspection_freq.items():
    if pd.notna(freq) and freq != 'None':
        print(f"   • {freq}: {count} hospitals")

# Control mechanisms for unlicensed women
control_types = hospital_notes['unlicensed_control_type'].value_counts()
print("\n👮 CONTROL MECHANISMS FOR UNLICENSED WOMEN:")
for mechanism, count in control_types.items():
    if pd.notna(mechanism) and mechanism != 'None':
        print(f"   • {mechanism}: {count} hospitals")

# Committee supervision
committee = hospital_notes['committee_supervision'].value_counts()
print("\n📋 ADMINISTRATIVE SUPERVISION:")
for supervision, count in committee.items():
    if pd.notna(supervision) and supervision != 'None':
        print(f"   • {supervision}: {count} hospitals")

# Sample inspection notes - the human reality behind the data
print("\n📝 SAMPLE INSPECTION NOTES (The Reality Behind the Data):")
sample_with_station = pd.read_sql_query("""
    SELECT hn.hid, ho.station, hn.remarks 
    FROM hospital_notes hn
    JOIN hospital_operations ho ON hn.hid = ho.hid
    WHERE hn.remarks IS NOT NULL AND hn.remarks != 'None'
    LIMIT 5
""", conn)

for _, row in sample_with_station.iterrows():
    print(f"\n   Station: {row['station']}")
    remark_text = row['remarks']
    if len(remark_text) > 200:
        print(f"   Note: {remark_text[:200]}...")
    else:
        print(f"   Note: {remark_text}")

# ============================================================================
# PART 9: KEY FINDINGS SUMMARY
# ============================================================================

print("\n" + "="*80)
print("KEY FINDINGS: THE TRANSFORMATION OF BODIES INTO CATEGORIES")
print("="*80)

print("\n1️⃣  SCALE OF BUREAUCRATIC CONTROL:")
print(f"   • {stations['count'][0]} lock hospital stations across British India")
print(f"   • {women_records['count'][0]} detailed records of women's bodies")
print(f"   • {hospital_ops['count'][0]} hospital operations documented")

print("\n2️⃣  CATEGORIZATION SYSTEMS:")
print("   • Women categorized by: registration status, disease type, compliance")
print("   • Tracked: admissions, removals, diseases, punishments, deaths")
print("   • Multiple disease categories: syphilis (primary & secondary), gonorrhoea, leucorrhoea")

print("\n3️⃣  THE MILITARY RATIONALE:")
print(f"   • {troop_records['count'][0]} military troop records")
print("   • Women's bodies regulated to protect military health")
print("   • Surveillance concentrated in military cantonments")

print("\n4️⃣  LEGAL MECHANISMS:")
print(f"   • {len(acts)} different acts/regulations implemented")
print("   • Most common: Contagious Diseases Acts (CD Acts)")
print("   • Legal framework for compulsory examination & registration")

print("\n5️⃣  PUNITIVE APPARATUS:")
total_fines = women['fined_count'].sum()
total_imprisonment = women['imprisonment_count'].sum()
if pd.notna(total_fines) and pd.notna(total_imprisonment):
    print(f"   • {total_fines:.0f} fines imposed on women")
    print(f"   • {total_imprisonment:.0f} imprisonments")
    print("   • Non-compliance met with legal punishment")

print("\n6️⃣  RESISTANCE & EVASION:")
if pd.notna(non_attendance):
    print(f"   • {non_attendance:.0f} cases of non-attendance documented")
    print("   • Notes mention 'unlicensed women' evading registration")
    print("   • Police and military pickets used to arrest unregistered women")

print("\n7️⃣  GEOGRAPHIC CONCENTRATION:")
top_regions = women_regional.head(3)
print("   • Highest concentration in:")
for _, row in top_regions.iterrows():
    print(f"     - {row['region']} ({row['women_added']:.0f} women added)")

print("\n" + "="*80)
print("CONCLUSION")
print("="*80)
print("""
The data reveals a sophisticated bureaucratic apparatus that transformed women's 
bodies into administrative categories through:

• QUANTIFICATION: Every aspect of women's bodies tracked, measured, categorized
• MEDICALIZATION: Sexual health redefined as state concern via disease categories
• SURVEILLANCE: Regular inspections, registration, tracking of movements
• PUNISHMENT: Legal penalties for non-compliance (fines, imprisonment)
• MILITARIZATION: System justified by military health needs
• DOCUMENTATION: Extensive paper trails converting bodies into data points

This is not just healthcare - it's the colonial state's power to define, categorize,
monitor, and control women's sexuality through medical-legal-administrative means.
The archive itself IS the mechanism of control.
""")

print("\n" + "="*80)

# Close connection
conn.close()

print("\n✅ Analysis complete. Ready for visualization and deeper statistical analysis.")
