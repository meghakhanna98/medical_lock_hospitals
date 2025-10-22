import sqlite3
import pandas as pd
import re

def clean_text(text):
    if pd.isna(text):
        return None
    # Remove extra whitespace
    text = ' '.join(text.split())
    # Remove leading/trailing whitespace
    return text.strip()

def standardize_class(value):
    if pd.isna(value):
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
    if pd.isna(value):
        return None
    value = value.lower().strip()
    # Standardize common variations
    if 'xiv' in value and '1868' in value:
        return 'Act XIV of 1868'
    elif 'xxii' in value and '1864' in value:
        return 'Act XXII of 1864'
    elif 'iii' in value and '1880' in value:
        return 'Act III of 1880'
    return value.title()

# Connect to the database
conn = sqlite3.connect('medical_lock_hospitals.db')

# Query to get all hospital operations data
query = "SELECT * FROM hospital_operations"
df = pd.read_sql_query(query, conn)

# Show current unique values before standardization
print("\nBefore Standardization:")
print("\nUnique values in 'class' field:")
print(df['class'].value_counts().to_string())
print("\nUnique values in 'act' field:")
print(df['act'].value_counts().to_string())

# Analyze regions and countries
print("\nUnique values in 'region' field:")
print(df['region'].value_counts().to_string())
print("\nUnique values in 'country' field:")
print(df['country'].value_counts().to_string())

# Clean and standardize the data
df['class'] = df['class'].apply(standardize_class)
df['act'] = df['act'].apply(standardize_act)
df['region'] = df['region'].apply(clean_text)
df['country'] = df['country'].apply(clean_text)

print("\nAfter Standardization:")
print("\nStandardized 'class' values:")
print(df['class'].value_counts().to_string())
print("\nStandardized 'act' values:")
print(df['act'].value_counts().to_string())
print("\nStandardized 'region' values:")
print(df['region'].value_counts().to_string())
print("\nStandardized 'country' values:")
print(df['country'].value_counts().to_string())

# Show the number of records affected by standardization
print("\nStandardization Impact:")
print(f"Total records: {len(df)}")
print(f"Records with non-null class: {df['class'].notna().sum()}")
print(f"Records with non-null act: {df['act'].notna().sum()}")

# Close the connection
conn.close()
/Users/meghakhanna/medical_lock_hospitals/.venv/bin/python - <<'PY'
import sqlite3
conn=sqlite3.connect('medical_lock_hospitals.db')
c=conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
print("tables:", [r[0] for r in c.fetchall()])
c.execute("PRAGMA table_info(hospital_operations)")
print("schema:", c.fetchall())
c.execute("SELECT COUNT(*) FROM hospital_operations")
print("count:", c.fetchone()[0])
c.execute("SELECT * FROM hospital_operations LIMIT 5")
print("sample:", c.fetchall())
conn.close()
PY
