# Snakefile for bacterial genome assembly and annotation pipeline

import os
import glob

# Load config
configfile: "config.yaml"

# Wildcards for strains
STRAINS = glob_wildcards(config["raw_data_dir"] + "/{strain}/").strain

# Rule all: aggregate final outputs
rule all:
    input:
        expand("results/006_pgap/{strain}/pgap_output", strain=STRAINS)

# Rule merge: combine raw reads for each strain
rule merge:
    input:
        # Function to collect all fastq.gz files for a given strain
        lambda wildcards: glob.glob(os.path.join(config["raw_data_dir"], wildcards.strain, "*.fastq.gz"))
    output:
        "results/001_merge/{strain}/merged.fastq.gz"
    threads: config["threads"]["merge"]
    resources:
        mem_mb=config["resources"]["merge"]["mem_mb"],
        time_min=config["resources"]["merge"]["time_min"]
    shell:
        """
        mkdir -p {output[0].parent}
        # TODO: Implement bash logic to merge FASTQ files
        # Example: cat {input} > {output}
        # Or use seqkit concat: seqkit concat {input} -o {output}
        """

# Rule flye1: initial assembly with Flye
rule flye1:
    input:
        "results/001_merge/{strain}/merged.fastq.gz"
    output:
        assembly="results/002_flye1/{strain}/assembly.fasta",
        log="results/002_flye1/{strain}/flye.log"
    threads: config["threads"]["flye"]
    resources:
        mem_mb=config["resources"]["flye"]["mem_mb"],
        time_min=config["resources"]["flye"]["time_min"]
    conda:
        "envs/flye.yaml"
    shell:
        """
        mkdir -p {output.assembly.parent}
        # TODO: Implement Flye command
        # Example: flye --nano-raw {input} --out-dir {output.assembly.parent} --threads {threads} {config[flye].extra}
        # Note: Adjust parameters as needed, e.g., genome size
        """

# Rule parse_flye1_length: extract max contig length from assembly
rule parse_flye1_length:
    input:
        "results/002_flye1/{strain}/assembly.fasta"
    output:
        "results/002_flye1/{strain}/max_contig_length.txt"
    threads: 1
    resources:
        mem_mb=config["resources"]["merge"]["mem_mb"],  # small job
        time_min=config["resources"]["merge"]["time_min"]
    shell:
        """
        mkdir -p {output[0].parent}
        python scripts/get_max_contig_length.py {input} {output}
        """

# Rule filtlong: filter reads based on max contig length
rule filtlong:
    input:
        reads="results/001_merge/{strain}/merged.fastq.gz",
        max_len="results/002_flye1/{strain}/max_contig_length.txt"
    output:
        "results/003_filtlong/{strain}/filtered.fastq.gz"
    threads: config["threads"]["filtlong"]
    resources:
        mem_mb=config["resources"]["filtlong"]["mem_mb"],
        time_min=config["resources"]["filtlong"]["time_min"]
    conda:
        "envs/filtlong.yaml"
    params:
        # Function to compute keep_bases from max_contig_length.txt using multiplier from config
        keep_bases=lambda wildcards: int(open("results/002_flye1/{strain}/max_contig_length.txt".format(strain=wildcards.strain)).read().strip()) * config["filtlong"]["target_base_multiplier"]
    shell:
        """
        mkdir -p {output[0].parent}
        # TODO: Implement filtlong command
        # Example: filtlong --target_bases {params.keep_bases} --min_length {config[filtlong].min_length} --keep_percent {config[filtlong].keep_percent} {input.reads} > {output}
        """

# Rule flye2: final assembly with Flye on filtered reads
rule flye2:
    input:
        "results/003_filtlong/{strain}/filtered.fastq.gz"
    output:
        "results/004_flye2/{strain}/final_assembly.fasta"
    threads: config["threads"]["flye"]
    resources:
        mem_mb=config["resources"]["flye"]["mem_mb"],
        time_min=config["resources"]["flye"]["time_min"]
    conda:
        "envs/flye.yaml"
    shell:
        """
        mkdir -p {output[0].parent}
        # TODO: Implement Flye command (similar to flye1 but on filtered reads)
        # Example: flye --nano-raw {input} --out-dir {output[0].parent} --threads {threads} {config[flye].extra}
        """

# Rule taxcheck: run taxcheck on assembly
rule taxcheck:
    input:
        "results/004_flye2/{strain}/final_assembly.fasta"
    output:
        "results/005_taxcheck/{strain}/taxcheck_report.txt"
    threads: config["threads"]["taxcheck"]
    resources:
        mem_mb=config["resources"]["taxcheck"]["mem_mb"],
        time_min=config["resources"]["taxcheck"]["time_min"]
    conda:
        "envs/ncbi-pgap.yaml"
    shell:
        """
        mkdir -p {output[0].parent}
        # TODO: Implement pgap.py taxcheck-only command
        # Example: pgap.py --taxcheck-only {input} --output {output[0].parent}
        """

# Rule parse_taxcheck: extract species name from taxcheck report
rule parse_taxcheck:
    input:
        "results/005_taxcheck/{strain}/taxcheck_report.txt"
    output:
        "results/005_taxcheck/{strain}/species_name.txt"
    threads: 1
    resources:
        mem_mb=config["resources"]["merge"]["mem_mb"],
        time_min=config["resources"]["merge"]["time_min"]
    shell:
        """
        mkdir -p {output[0].parent}
        python scripts/get_species_name.py {input} {output}
        """

# Rule pgap_annotation: run full PGAP annotation
rule pgap_annotation:
    input:
        fasta="results/004_flye2/{strain}/final_assembly.fasta",
        species="results/005_taxcheck/{strain}/species_name.txt"
    output:
        directory("results/006_pgap/{strain}/pgap_output")
    threads: config["threads"]["pgap"]
    resources:
        mem_mb=config["resources"]["pgap"]["mem_mb"],
        time_min=config["resources"]["pgap"]["time_min"]
    conda:
        "envs/ncbi-pgap.yaml"
    params:
        # Function to read species name from file
        species_name=lambda wildcards: open("results/005_taxcheck/{strain}/species_name.txt".format(strain=wildcards.strain)).read().strip()
    shell:
        """
        mkdir -p {output}
        # TODO: Implement full pgap.py annotation command
        # Example with Docker support:
        # if {config[pgap][use_docker]}; then
        #   docker run {config[pgap][docker_options]} {config[pgap][docker_image]} pgap.py -t {threads} -o {output} -s {params.species_name} {input.fasta}
        # else
        #   pgap.py -t {threads} -o {output} -s {params.species_name} {input.fasta}
        # fi
        """