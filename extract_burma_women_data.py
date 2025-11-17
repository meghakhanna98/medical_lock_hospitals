#!/usr/bin/env python3
"""
Extract women registration data from Burma PDF
Looking for: Women on register at start of year, Women added during the year
"""

import pdfplumber
import re
import sys

def extract_women_data(pdf_path):
    """Extract women data tables from PDF"""
    
    print("Opening PDF:", pdf_path)
    print("=" * 80)
    
    with pdfplumber.open(pdf_path) as pdf:
        print(f"\nTotal pages: {len(pdf.pages)}\n")
        
        # Track data found
        all_data = []
        
        for page_num, page in enumerate(pdf.pages, 1):
            text = page.extract_text()
            
            if not text:
                continue
            
            # Look for keywords that indicate women registration data
            if any(keyword in text.lower() for keyword in [
                'women on register',
                'women added',
                'lock hospital',
                'registered women',
                'prostitutes'
            ]):
                print(f"\n{'=' * 80}")
                print(f"PAGE {page_num} - Contains women registration keywords")
                print(f"{'=' * 80}\n")
                
                # Try to extract tables
                tables = page.extract_tables()
                
                if tables:
                    for table_idx, table in enumerate(tables, 1):
                        print(f"\n--- Table {table_idx} on Page {page_num} ---")
                        
                        # Print table headers and first few rows
                        for row_idx, row in enumerate(table[:10]):  # First 10 rows
                            if row:
                                clean_row = [str(cell).strip() if cell else '' for cell in row]
                                print(' | '.join(clean_row))
                        
                        if len(table) > 10:
                            print(f"... ({len(table) - 10} more rows)")
                        
                        # Check if this table has our columns
                        header_text = ' '.join([str(cell).lower() for cell in table[0] if cell])
                        if 'women' in header_text or 'register' in header_text or 'added' in header_text:
                            all_data.append({
                                'page': page_num,
                                'table': table_idx,
                                'data': table
                            })
                
                # Also print raw text excerpts mentioning years 1880-1882
                lines = text.split('\n')
                for line in lines:
                    if any(year in line for year in ['1880', '1881', '1882']):
                        if any(keyword in line.lower() for keyword in ['women', 'register', 'added', 'prostitute']):
                            print(f"  YEAR MENTION: {line.strip()}")
        
        print(f"\n\n{'=' * 80}")
        print(f"SUMMARY: Found {len(all_data)} relevant tables")
        print(f"{'=' * 80}")
        
        return all_data

if __name__ == '__main__':
    pdf_path = '/Users/meghakhanna/Downloads/Burma copy-compressed.pdf'
    
    if len(sys.argv) > 1:
        pdf_path = sys.argv[1]
    
    try:
        data = extract_women_data(pdf_path)
        
        if data:
            print("\n\nRELEVANT TABLES FOUND:")
            for item in data:
                print(f"  - Page {item['page']}, Table {item['table']}")
        else:
            print("\nNo tables with women registration data found.")
            print("The PDF might use images or non-standard formatting.")
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
