#!/usr/bin/env python3
"""
Script to remove unused output blocks from app.R
Stage 2 of cleanup: removing server outputs for deleted tabs
"""

import re

# Define all the unused output names that need to be removed
UNUSED_OUTPUTS = [
    'med_men_network',
    'med_women_network',
    'med_temporal_women_added',
    'med_temporal_avg_registered',
    'med_temporal_ops_over_time',
    'med_temporal_records_created',
    'med_geo_women_added_by_region',
    'med_geo_avg_registered_by_region',
    'med_disease_pie',
    'med_disease_bar',
    'med_surveillance_sankey',
    'med_acts_total',
    'med_acts_timeline',
    'med_acts_by_station',
    'acts_animated_map',
    'acts_year_summary',
    'med_summary_html',
    'correlation_dual_axis',
    'correlation_scatter',
    'correlation_metrics_table',
    'admissions_women_by_region',
    'admissions_men_by_region',
    'animated_timeline_map',
    'timeline_year_metrics',
    'disease_prevalence_map',
    'disease_comparison_women',
    'disease_comparison_troops',
    'ops_debug_info',
    'ops_inspection_timeline',
    'ops_inspection_by_region',
    'ops_unlicensed_methods',
    'ops_unlicensed_by_act',
    'ops_committee_distribution',
    'ops_committee_by_region',
    'ops_punishment_timeline',
    'ops_punishment_by_station',
    'ops_staff_mentions_timeline',
    'ops_staff_mentions_by_region',
]

def find_output_blocks(lines):
    """
    Find all output blocks and their line ranges.
    Each output block starts with '  output$name <-' and ends with the matching '})' 
    Returns: list of (start_line, end_line, output_name, should_remove)
    """
    blocks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Look for output$ assignments at exactly 2-space indent
        match = re.match(r'^  output\$(\w+)\s*<-\s*(\w+)\(', line)
        if match:
            output_name = match.group(1)
            render_func = match.group(2)
            start_line = i
            
            # Track brace/paren nesting to find the matching closing
            depth = 0
            # Count opening parens/braces in first line
            depth += line.count('(') - line.count(')')
            depth += line.count('{') - line.count('}')
            
            j = i + 1
            while j < len(lines) and depth > 0:
                next_line = lines[j]
                depth += next_line.count('(') - next_line.count(')')
                depth += next_line.count('{') - next_line.count('}')
                j += 1
            
            # End line is where depth returned to 0
            end_line = j - 1
            
            should_remove = output_name in UNUSED_OUTPUTS
            blocks.append((start_line, end_line, output_name, should_remove))
            i = j
        else:
            i += 1
    
    return blocks

def remove_blocks(input_file, output_file):
    """Remove unused output blocks from the file"""
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    blocks = find_output_blocks(lines)
    
    # Print what we found
    print(f"Found {len(blocks)} output blocks:")
    print(f"\nBlocks to REMOVE:")
    for start, end, name, remove in blocks:
        if remove:
            print(f"  Lines {start+1:4d}-{end+1:4d} ({end-start+1:3d} lines): output${name}")
    
    print(f"\nBlocks to KEEP:")
    for start, end, name, remove in blocks:
        if not remove:
            print(f"  Lines {start+1:4d}-{end+1:4d} ({end-start+1:3d} lines): output${name}")
    
    # Calculate total lines to remove
    total_removed = sum(end - start + 1 for start, end, _, remove in blocks if remove)
    print(f"\nTotal lines to remove: {total_removed}")
    print(f"File size: {len(lines)} -> {len(lines) - total_removed}")
    
    # Create new file content
    kept_lines = []
    lines_to_skip = set()
    
    for start, end, _, remove in blocks:
        if remove:
            for line_num in range(start, end + 1):
                lines_to_skip.add(line_num)
    
    for i, line in enumerate(lines):
        if i not in lines_to_skip:
            kept_lines.append(line)
    
    # Write output
    with open(output_file, 'w') as f:
        f.writelines(kept_lines)
    
    print(f"\nWrote cleaned file to: {output_file}")
    return len(lines), len(kept_lines), total_removed

if __name__ == '__main__':
    input_file = 'app.R'
    output_file = 'app_cleaned.R'
    
    original_lines, new_lines, removed_lines = remove_blocks(input_file, output_file)
    
    print(f"\n✓ Cleanup complete!")
    print(f"  Original: {original_lines} lines")
    print(f"  Removed:  {removed_lines} lines")
    print(f"  New file: {new_lines} lines")
    print(f"\nNext steps:")
    print(f"  1. Review: diff app.R app_cleaned.R | less")
    print(f"  2. Backup: cp app.R app.R.before_stage2")
    print(f"  3. Replace: mv app_cleaned.R app.R")
    print(f"  4. Test: R -e 'shiny::runApp()'")
