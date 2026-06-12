#!/usr/bin/env python3
"""
Script to extract maximum contig length from a FASTA file.
Usage: python get_max_contig_length.py <input_fasta> <output_txt>
"""
import sys
import os

def get_max_contig_length(fasta_file):
    """Calculate the maximum contig length from a FASTA file."""
    max_length = 0
    current_length = 0
    
    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                # New contig header
                if current_length > max_length:
                    max_length = current_length
                current_length = 0
            else:
                # Sequence line
                current_length += len(line)
        
        # Check last contig
        if current_length > max_length:
            max_length = current_length
    
    return max_length

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python get_max_contig_length.py <input_fasta> <output_txt>")
        sys.exit(1)
    
    input_fasta = sys.argv[1]
    output_txt = sys.argv[2]
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_txt), exist_ok=True)
    
    max_length = get_max_contig_length(input_fasta)
    
    with open(output_txt, 'w') as f:
        f.write(str(max_length))
    
    print(f"Maximum contig length: {max_length}")