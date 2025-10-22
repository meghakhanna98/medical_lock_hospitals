import sqlite3

def standardize_class(value):
    if not value:
        return None
    value = value.lower().strip()
    if 'first' in value or '1st' in value:
        return 'First Class'
    elif 'second' in value or '2nd' in value:
        return 'Second Class'
    elif 'third' in value or '3rd' in value:
        return 'Third Class'
    elif 'military' in value:
        return 'Military'
    elif 'civil' in value:
        return 'Civil'
    return value.title()

def standardize_act(value):
    if not value:
        return None
    value = value.lower().strip()
    
    # Extract act number and year only
    if 'xiv' in value and '1868' in value:
        return 'Act XIV of 1868'
    elif 'xxii' in value and '1864' in value:
        return 'Act XXII of 1864'
    elif 'iii' in value and '1880' in value:
        return 'Act III of 1880'
    elif 'xii' in value and '1864' in value:
        return 'Act XII of 1864'
    elif 'voluntary' in value:
        return 'Voluntary System'
    
    return value.title()

def standardize_country(value):
    if not value:
        return None
    value = value.lower().strip()
    
    if 'british india' in value:
        return 'British India'
    elif 'burma' in value:
        return 'British Burma'
    
    return value.title()

def standardize_region(value):
    if not value:
        return None
    value = value.lower().strip()
    
    # Standardize Madras Presidency variations
    if 'madras' in value:
        return 'Madras Presidency'
    
    # Replace British Burma variations with Burma
    if 'burma' in value:
        return 'Burma'
    
    # Standardize other regions
    if 'punjab' in value:
        return 'Punjab'
    elif 'central provinces' in value:
        return 'Central Provinces'
    elif 'north-western provinces' in value or 'oudh' in value:
        return 'North-Western Provinces & Oudh'
    
    return value.title()

def main():
    conn = sqlite3.connect('medical_lock_hospitals.db')
    cursor = conn.cursor()
    
    print("Starting database update...")
    
    # Back up current data
    cursor.execute('SELECT * FROM hospital_operations')
    all_data = cursor.fetchall()
    cursor.execute('PRAGMA table_info(hospital_operations)')
    columns = cursor.fetchall()
    column_names = [col[1] for col in columns]
    
    # Drop existing table
    cursor.execute('DROP TABLE IF EXISTS hospital_operations')
    
    # Create new table without staff columns
    cursor.execute('''
        CREATE TABLE hospital_operations (
            hid TEXT PRIMARY KEY,
            doc_id TEXT,
            source_name TEXT,
            source_type TEXT,
            year INTEGER,
            region TEXT,
            station TEXT,
            country TEXT,
            act TEXT,
            class TEXT,
            FOREIGN KEY (doc_id) REFERENCES documents (doc_id)
        )
    ''')
    
    # Get indices for the columns we want to keep
    keep_indices = [
        column_names.index('hid'),
        column_names.index('doc_id'),
        column_names.index('source_name'),
        column_names.index('source_type'),
        column_names.index('year'),
        column_names.index('region'),
        column_names.index('station'),
        column_names.index('country'),
        column_names.index('act'),
        column_names.index('class')
    ]
    
    # Insert data back and standardize
    print("Reinserting and standardizing data...")
    for row in all_data:
        # Extract only the columns we want to keep
        new_row = [row[i] for i in keep_indices]
        
        # Standardize the values
        new_row[8] = standardize_act(new_row[8])      # act
        new_row[9] = standardize_class(new_row[9])    # class
        new_row[7] = standardize_country(new_row[7])  # country
        new_row[5] = standardize_region(new_row[5])   # region
        
        cursor.execute('''
            INSERT INTO hospital_operations 
            (hid, doc_id, source_name, source_type, year, region, station, country, act, class)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', new_row)
    
    conn.commit()
    
    # Verify unique values after standardization
    print("\nVerifying standardization results...")
    for field in ['class', 'act', 'country', 'region']:
        cursor.execute(f'SELECT DISTINCT {field} FROM hospital_operations WHERE {field} IS NOT NULL ORDER BY {field}')
        values = cursor.fetchall()
        print(f"\nUnique values in {field} after standardization:")
        for value in values:
            print(f"  - {value[0]}")
    
    conn.close()
    print("\nStandardization complete!")

if __name__ == '__main__':
    main()