# Bacterial Genome Assembly and Annotation Pipeline

A Snakemake pipeline for the assembly and annotation of bacterial genomes from long-read sequencing data (ONT/PacBio). This pipeline performs read merging, initial assembly, read filtering based on assembly metrics, final assembly, taxonomic classification, and functional annotation using PGAP.

## Table of Contents
- [Overview](#overview)
- [Pipeline Stages](#pipeline-stages)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Expected Input Data](#expected-input-data)
- [Output Structure](#output-structure)
- [Example Runs](#example-runs)
- [Dependencies](#dependencies)
- [Customization](#customization)

## Overview

This pipeline automates the process of bacterial genome analysis from raw long-read data to fully annotated assemblies. It incorporates best practices for assembly improvement through read filtering based on initial assembly metrics and ensures proper taxonomic annotation.

The pipeline consists of the following stages:
1. Read merging
2. Initial assembly (Flye)
3. Max contig length extraction
4. Read filtering (Filtlong)
5. Final assembly (Flye)
6. Taxonomic check (PGAP taxcheck)
7. Species name extraction
8. Functional annotation (PGAP)

## Pipeline Stages

### 1. Read Merging (`merge`)
Combines all FASTQ files for each strain into a single merged FASTQ file.

### 2. Initial Assembly (`flye1`)
Runs Flye on merged reads to produce an initial assembly.

### 3. Max Contig Length Extraction (`parse_flye1_length`)
Calculates the length of the longest contig from the initial assembly using a dedicated Python script.

### 4. Read Filtering (`filtlong`)
Filters the merged reads based on the max contig length (multiplied by a configurable factor) to enrich for high-quality, long reads.

### 5. Final Assembly (`flye2`)
Runs Flye on the filtered reads to produce a refined assembly.

### 6. Taxonomic Check (`taxcheck`)
Runs PGAP in taxcheck-only mode to determine the taxonomic classification of the assembly.

### 7. Species Name Extraction (`parse_taxcheck`)
Extracts the recommended species name from the PGAP taxcheck report using a dedicated Python script.

### 8. Functional Annotation (`pgap_annotation`)
Runs full PGAP annotation on the final assembly using the identified species name.

## Installation

### Prerequisites
- [Snakemake](https://snakemake.readthedocs.io/) (version 7.0 or higher)
- [Mamba](https://mamba.readthedocs.io/) or [Conda](https://docs.conda.io/) (for environment management)
- Docker (optional, for PGAP execution)

### Setup
1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. The pipeline uses Conda environments defined in the `envs/` directory. These will be automatically created by Snakemake when needed.

3. Ensure you have the required tools installed:
   ```bash
   # Install Snakemake and Mamba if not present
   conda install -c bioconda -c conda-forge snakemake mamba
   ```

## Usage

### Basic Execution
To run the pipeline for all strains found in `raw_data/`:
```bash
snakemake --cores N
```
Where `N` is the number of CPU cores to use.

### Specific Strain
To run for a specific strain (e.g., `strain1`):
```bash
snakemake --cores N results/006_pgap/strain1/pgap_output
```

### Dry Run
To see what would be executed without actually running:
```bash
snakemake --cores N -n
```

### With Debugging
To see detailed debugging information:
```bash
snakemake --cores N -r -p
```

### Cluster Execution
For cluster execution (adjust the cluster configuration as needed):
```bash
snakemake --cores N --cluster "sbatch -t {resources.time_min} --mem={resources.mem_mb} -c {threads}"
```

## Configuration

The pipeline is configured through `config.yaml`:

### Key Configuration Sections

#### Directories
```yaml
raw_data_dir: "raw_data"      # Input data directory
output_dir: "results"         # Base output directory
scripts_dir: "scripts"        # Directory containing helper scripts
```

#### Threads and Resources
```yaml
threads:
  merge: 2
  flye: 8
  filtlong: 4
  taxcheck: 2
  pgap: 8

resources:
  merge:
    mem_mb: 1000
    time_min: 30
  flye:
    mem_mb: 32000
    time_min: 1440  # 24 hours
  filtlong:
    mem_mb: 8000
    time_min: 60
  taxcheck:
    mem_mb: 4000
    time_min: 60
  pgap:
    mem_mb: 16000
    time_min: 1440  # 24 hours
```

#### Tool Parameters
```yaml
flye:
  genome_size: "5m"  # Adjust based on expected genome size

filtlong:
  min_length: 1000
  keep_percent: 90
  target_base_multiplier: 120  # Multiplier for max contig length

pgap:
  force: false
  use_docker: false  # Set to true to use Docker for PGAP
  docker_image: "ncbi/pgap:latest"
  docker_options: "--rm -v $(pwd):/data"
```

### Expected Input Data

The pipeline expects the following directory structure:
```
raw_data/
├── strain1/
│   ├── sample1_fastq.gz
│   ├── sample2_fastq.gz
│   └ ...
├── strain2/
│   ├── sample1_fastq.gz
│   └ ...
└ ...
```

Each strain directory should contain one or more gzipped FASTQ files (.fastq.gz or .fq.gz) representing long-read sequencing data (ONT or PacBio).

### Output Structure

Results will be organized in the `results/` directory as follows:
```
results/
├── 001_merge/
│   └── strain1/
│       └── merged.fastq.gz
├── 002_flye1/
│   └── strain1/
│       ├── assembly.fasta
│       ├── flye.log
│       └── max_contig_length.txt
├── 003_filtlong/
│   └── strain1/
│       └── filtered.fastq.gz
├── 004_flye2/
│   └── strain1/
│       └── final_assembly.fasta
├── 005_taxcheck/
│   └── strain1/
│       ├── taxcheck_report.txt
│       └── species_name.txt
└── 006_pgap/
    └── strain1/
        └── pgap_output/          # Directory containing PGAP annotation results
```

## Example Runs

### Example 1: Simple Local Run
```bash
# Run with 4 cores
snakemake --cores 4
```

### Example 2: High-Performance Cluster
```bash
# Submit to SLURM cluster
snakemake --cores 20 \
  --cluster "sbatch -t {resources.time_min} --mem={resources.mem_mb} -c {threads} -p short" \
  --jobs 10 \
  --latency-wait 60
```

### Example 3: Using Docker for PGAP
First, update config.yaml:
```yaml
pgap:
  use_docker: true
  docker_image: "ncbi/pgap:latest"
  docker_options: "--rm -v $(pwd):/data -v /tmp:/tmp"
```

Then run normally:
```bash
snakemake --cores 8
```

### Example 4: Targeting Specific Output
To generate only the merged reads for all strains:
```bash
snakemake --cores 4 results/001_merge/{strain}/merged.fastq.gz
```

## Dependencies

The pipeline uses the following tools, automatically installed in isolated Conda environments:

- **Flye** (v2.9): For long-read assembly
- **Filtlong** (v0.2.1): For read filtering
- **NCBI PGAP** (2022-09-28.001): For taxonomic annotation and functional annotation
- **Python** (3.8): For helper scripts

Helper scripts:
- `get_max_contig_length.py`: Extracts maximum contig length from FASTA
- `get_species_name.py`: Extracts species name from PGAP taxcheck report

## Customization

### Modifying Parameters
Edit `config.yaml` to adjust:
- Thread and resource allocations
- Flye parameters (genome size, etc.)
- Filtlong parameters (min length, keep percent, target base multiplier)
- PGAP parameters (force annotation, Docker usage)

### Adding New Strains
Simply add new directories to `raw_data/`:
```
raw_data/
├── existing_strain/
│   └── *.fastq.gz
└── new_strain/
    └── *.fastq.gz
```
The pipeline will automatically detect the new strain via wildcard.

### Changing Output Directory
Modify the `output_dir` parameter in `config.yaml`.

### Using Different Assemblers
To substitute Flye with another assembler:
1. Update the `flye1` and `flye2` rules in Snakefile
2. Adjust the conda environment in `envs/flye.yaml`
3. Update any Flye-specific parameters in config.yaml