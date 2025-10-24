import sqlite3
import os
import shutil
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'medical_lock_hospitals.db')
DB_PATH = os.path.abspath(DB_PATH)
BACKUP_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'archive', 'backups'))
os.makedirs(BACKUP_DIR, exist_ok=True)

print("Using DB:", DB_PATH)

# 1) Backup database
stamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')
backup_path = os.path.join(BACKUP_DIR, f'medical_lock_hospitals_backup_{stamp}.db')
shutil.copy2(DB_PATH, backup_path)
print(f"Backup created: {backup_path}")

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

# Helper to run UPDATE for a table & column

def update_station_name(table, column, where_clause, params):
    sql = f"UPDATE {table} SET {column} = ? WHERE {where_clause}"
    cur.execute(sql, params)
    return cur.rowcount

# 2) Standardize 'India (British Burma)' variants to 'Rangoon' across relevant tables
rangoon_targets = [
    ('hospital_operations', 'station'),
    ('women_admission', 'station'),
    ('women_data', 'station'),
    ('troops', 'station'),
    ('troop_data', 'station')
]

changed_total = 0
for table, col in rangoon_targets:
    # exact lower match and +G143 variant
    rc1 = update_station_name(table, col, f"LOWER({col}) = 'india (british burma)'", ("Rangoon",))
    rc2 = update_station_name(table, col, f"{col} = 'India (British Burma)+G143'", ("Rangoon",))
    # sometimes stray spaces or case differences
    rc3 = update_station_name(table, col, f"LOWER({col}) LIKE 'india (british burma)%'", ("Rangoon",))
    changed_total += (rc1 + rc2 + rc3)
    print(f"{table}: updated to Rangoon -> {rc1 + rc2 + rc3}")

# Stations table: merge any 'India (British Burma)%' rows into existing 'Rangoon' if present
cur.execute("SELECT station_id FROM stations WHERE name = 'Rangoon'")
row = cur.fetchone()
rangoon_id = row[0] if row else None

cur.execute("SELECT station_id, name FROM stations WHERE LOWER(name) LIKE 'india (british burma)%'")
dups = cur.fetchall()
merged = 0
for old_id, old_name in dups:
    if rangoon_id is not None:
        # Repoint station_reports
        cur.execute("UPDATE station_reports SET station_id = ? WHERE station_id = ?", (rangoon_id, old_id))
        # Delete old station row
        cur.execute("DELETE FROM stations WHERE station_id = ?", (old_id,))
        merged += 1
        print(f"stations: merged '{old_name}' (id={old_id}) into 'Rangoon' (id={rangoon_id})")
    else:
        # No existing Rangoon; safe to rename
        cur.execute("UPDATE stations SET name = 'Rangoon' WHERE station_id = ?", (old_id,))
        print(f"stations: renamed '{old_name}' to 'Rangoon'")
        merged += 1
print(f"stations: Rangoon merge/rename operations -> {merged}")

# 3) Unify Seetabuldee / Sitabaldi to 'Sitabaldi (Nagpur)' and set coordinates

def set_coords(name_like_conditions, new_name, lat, lon):
    # Ensure a single canonical station row named `new_name`
    cur.execute("SELECT station_id FROM stations WHERE name = ?", (new_name,))
    row = cur.fetchone()
    canonical_id = row[0] if row else None

    for cond in name_like_conditions:
        # Find all matching rows that are NOT the canonical
        cur.execute("SELECT station_id, name FROM stations WHERE " + cond + " AND name <> ?", (new_name,))
        matches = cur.fetchall()
        for old_id, old_name in matches:
            if canonical_id is None:
                # Make this one the canonical by renaming
                cur.execute("UPDATE stations SET name = ? WHERE station_id = ?", (new_name, old_id))
                canonical_id = old_id
                print(f"stations: promoted '{old_name}' (id={old_id}) to canonical '{new_name}'")
            else:
                # Repoint station_reports and delete duplicate
                cur.execute("UPDATE station_reports SET station_id = ? WHERE station_id = ?", (canonical_id, old_id))
                cur.execute("DELETE FROM stations WHERE station_id = ?", (old_id,))
                print(f"stations: merged duplicate '{old_name}' (id={old_id}) into canonical id={canonical_id}")

    # Set coordinates on the canonical row if it exists now
    cur.execute("UPDATE stations SET latitude = ?, longitude = ? WHERE name = ?", (lat, lon, new_name))
    print(f"stations: set coords for '{new_name}' -> {cur.rowcount}")

    # Update station names in data tables as well
    for table, col in rangoon_targets:
        for cond in name_like_conditions:
            cond_col = cond.replace('name', col)
            cur.execute(f"UPDATE {table} SET {col} = ? WHERE " + cond_col, (new_name,))
            print(f"{table}: standardized to '{new_name}' for condition [{cond_col}] -> {cur.rowcount}")

set_coords([
    "LOWER(name) LIKE 'seetabuldee%'",
    "LOWER(name) LIKE 'sitabaldi%'"
], "Sitabaldi (Nagpur)", 21.1430, 79.0871)

# 4) Coordinates updates for specific stations (keep names as-is, just set coords)
coords = {
    # name_like : (lat, lon)
    "LOWER(name) LIKE 'tonghoo%'": (18.9398, 96.4344),
    "LOWER(name) LIKE 'jubbulpore%'": (23.1686, 79.9339),
    "LOWER(name) LIKE 'muttra%'": (27.4924, 77.6737),
    "LOWER(name) LIKE 'umballa%'": (30.3752, 76.7821),
    "LOWER(name) LIKE 'meean meer%'": (31.5484, 74.3602),
    "LOWER(name) LIKE 'fyzabad%'": (26.7730, 82.1458),
    "LOWER(name) LIKE 'mooltan%'": (30.1979793, 71.4724978)
}

for cond, (lat, lon) in coords.items():
    cur.execute("UPDATE stations SET latitude = ?, longitude = ? WHERE " + cond, (lat, lon))
    print(f"stations: coords set for [{cond}] -> {cur.rowcount}")

conn.commit()

# 5) Quick summary checks
print("\n=== SUMMARY CHECKS ===")
for q in [
    ("SELECT COUNT(*) FROM hospital_operations WHERE station = 'Rangoon'", "ops->Rangoon"),
    ("SELECT COUNT(*) FROM women_admission WHERE station = 'Rangoon'", "women->Rangoon"),
    ("SELECT COUNT(*) FROM troops WHERE station = 'Rangoon'", "troops->Rangoon"),
    ("SELECT COUNT(*) FROM stations WHERE name = 'Rangoon'", "stations name=Rangoon"),
    ("SELECT name, latitude, longitude FROM stations WHERE LOWER(name) LIKE 'sitabaldi%"" OR LOWER(name) LIKE 'seetabuldee%' LIMIT 5", "Sitabaldi/Seetabuldee samples"),
    ("SELECT name, latitude, longitude FROM stations WHERE LOWER(name) LIKE 'tonghoo%' OR LOWER(name) LIKE 'mooltan%' OR LOWER(name) LIKE 'umballa%' OR LOWER(name) LIKE 'meean meer%' OR LOWER(name) LIKE 'fyzabad%' OR LOWER(name) LIKE 'jubbulpore%' OR LOWER(name) LIKE 'muttra%'", "Updated coord stations")
]:
    try:
        rows = conn.execute(q[0]).fetchall()
        print(q[1], "->", rows[:10])
    except Exception as e:
        print(q[1], "query failed:", e)

conn.close()
print("\nAll updates complete.")
