import pandas as pd
import sqlite3
from pathlib import Path

# Excel file path
excel_file = Path("/Users/meghakhanna/Desktop/Primary Sources/DS_Dataset.xlsx")

# Connect to SQLite database
conn = sqlite3.connect('medical_lock_hospitals.db')

try:
    # Read women admission data
    women_df = pd.read_excel(excel_file, sheet_name='Women_Admission')
    women_df.to_sql('women_admission', conn, if_exists='replace', index=False)
    print(f"Successfully imported {len(women_df)} rows into women_admission table")

    # Read troops data
    troops_df = pd.read_excel(excel_file, sheet_name='Troops')
    troops_df.to_sql('troops', conn, if_exists='replace', index=False)
    print(f"Successfully imported {len(troops_df)} rows into troops table")

except Exception as e:
    print(f"Error occurred: {str(e)}")

finally:
    conn.close()