#!/usr/bin/env python3
import sys
import os
import re

def extract_species_name(report_file):
    """Extract species name from PGAP taxcheck report."""
    species_name = None
    
    with open(report_file, 'r') as f:
        content = f.read()
        
        # Look for recommended species name pattern
        # Common patterns in PGAP taxcheck output
        patterns = [
            r'Recommended\s+species\s+name[:\s]+(.+)',
            r'Species[:\s]+(.+)',
            r'Organism[:\s]+(.+)',
            r'^(\S+\s+\S+)\s*$'  # Fallback: first two words that look like a species name
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content, re.IGNORECASE | re.MULTILINE)
            if match:
                species_name = match.group(1).strip()
                # Clean up the species name
                species_name = re.sub(r'\s+', ' ', species_name)  # Normalize whitespace
                break
    
    # If no species found, return a default or raise an error
    if species_name is None:
        # Try to extract from the first line that looks like a binomial name
        lines = content.split('\n')
        for line in lines:
            # Look for something like "Genus species"
            if re.match(r'^[A-Z][a-z]+\s+[a-z]+', line.strip()):
                species_name = line.strip()
                break
    
    # Final fallback
    if species_name is None:
        species_name = "unknown_species"
    
    return species_name

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python get_species_name.py <input_report> <output_txt>")
        sys.exit(1)
    
    input_report = sys.argv[1]
    output_txt = sys.argv[2]
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_txt), exist_ok=True)
    
    species_name = extract_species_name(input_report)
    
    with open(output_txt, 'w') as f:
        f.write(species_name)
    
    print(f"Extracted species name: {species_name}")