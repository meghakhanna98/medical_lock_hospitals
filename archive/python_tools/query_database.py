#!/usr/bin/env python3
import sqlite3

def query_database():
    """Demonstrate how to query the medical lock hospitals database"""
    
    conn = sqlite3.connect('medical_lock_hospitals.db')
    cursor = conn.cursor()
    
    print("=== Medical Lock Hospitals Database Queries ===\n")
    
    # Query 1: List all stations with their regions
    print("1. All Stations:")
    cursor.execute('''
        SELECT station_id, name, region, country 
        FROM stations 
        ORDER BY name
    ''')
    stations = cursor.fetchall()
    for station in stations[:10]:  # Show first 10
        print(f"  ID: {station[0]}, Name: {station[1]}, Region: {station[2]}, Country: {station[3]}")
    print(f"  ... and {len(stations) - 10} more stations\n")
    
    # Query 2: Count of records by year in women_data
    print("2. Women Data by Year:")
    cursor.execute('''
        SELECT year, COUNT(*) as count 
        FROM women_data 
        WHERE year IS NOT NULL 
        GROUP BY year 
        ORDER BY year
    ''')
    years = cursor.fetchall()
    for year, count in years:
        print(f"  {year}: {count} records")
    print()
    
    # Query 3: Troop data with average strength
    print("3. Troop Data (Top 10 by Average Strength):")
    cursor.execute('''
        SELECT station, regiments, avg_strength, year 
        FROM troop_data 
        WHERE avg_strength IS NOT NULL 
        ORDER BY avg_strength DESC 
        LIMIT 10
    ''')
    troops = cursor.fetchall()
    for troop in troops:
        print(f"  {troop[0]}: {troop[1]} - Strength: {troop[2]}, Year: {troop[3]}")
    print()
    
    # Query 4: Hospital operations by region
    print("4. Hospital Operations by Region:")
    cursor.execute('''
        SELECT region, COUNT(*) as count 
        FROM hospital_operations 
        GROUP BY region 
        ORDER BY count DESC
    ''')
    regions = cursor.fetchall()
    for region, count in regions:
        print(f"  {region}: {count} operations")
    print()
    
    # Query 5: Cross-table query - Documents with station reports
    print("5. Documents with Most Station Reports:")
    cursor.execute('''
        SELECT d.doc_id, d.source_name, COUNT(sr.report_id) as report_count
        FROM documents d
        LEFT JOIN station_reports sr ON d.doc_id = sr.doc_id
        GROUP BY d.doc_id, d.source_name
        ORDER BY report_count DESC
        LIMIT 5
    ''')
    docs = cursor.fetchall()
    for doc in docs:
        print(f"  {doc[0]}: {doc[2]} reports - {doc[1][:50]}...")
    
    conn.close()

if __name__ == "__main__":
    query_database()
