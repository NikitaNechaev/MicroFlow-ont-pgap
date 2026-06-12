import os
import glob

configfile: "config.yaml"

STRAINS = glob_wildcards(config["raw_data_dir"] + "/{strain}/").strain

rule all:
    input:
        expand("results/006_pgap/{strain}/pgap_output", strain=STRAINS)

rule merge:
    input:
        lambda wildcards: glob.glob(os.path.join(config["raw_data_dir"], wildcards.strain, "*.fastq.gz"))
    output:
        "results/000_merge/{strain}/merged.fastq.gz"
    threads: config["threads"]["merge"]
    resources:
        mem_mb=config["resources"]["merge"]["mem_mb"],
        time_min=config["resources"]["merge"]["time_min"]
    shell:
        """
        mkdir -p {output[0].parent}
        cat {input} > {output}
        """

rule nanoplot:
    input:
        "results/000_merge/{strain}/merged.fastq.gz"
    output:
        "results/001_nanoplot/{strain}/nanoplot_report.html"
    threads: 1
    resources:
        mem_mb=1000,
        time_min=30
    shell:
        """
        mkdir -p {output[0].parent}
        Nanoplot --fastq {input} --outdir {output[0].parent} --threads {threads}
        """

rule flye1:
    input:
        "results/000_merge/{strain}/merged.fastq.gz"
    output:
        assembly="results/003_flye1/{strain}/assembly.fasta",
        log="results/003_flye1/{strain}/flye.log"
    threads: config["threads"]["flye"]
    resources:
        mem_mb=config["resources"]["flye"]["mem_mb"],
        time_min=config["resources"]["flye"]["time_min"]
    conda:
        "envs/flye.yaml"
    shell:
        """
        mkdir -p {output.assembly.parent}
        flye --nano-raw {input} --out-dir {output.assembly.parent} --threads {threads} {config[flye].extra} --meta
        """

rule parse_flye1_length:
    input:
        "results/003_flye1/{strain}/assembly.fasta"
    output:
        "results/003_flye1/{strain}/max_contig_length.txt"
    threads: 1
    resources:
        mem_mb=config["resources"]["merge"]["mem_mb"],  # small job
        time_min=config["resources"]["merge"]["time_min"]
    shell:
        """
        mkdir -p {output[0].parent}
        python scripts/get_max_contig_length.py {input} {output}
        """

rule filtlong:
    input:
        reads="results/000_merge/{strain}/merged.fastq.gz",
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
        keep_bases=lambda wildcards: int(open("results/002_flye1/{strain}/max_contig_length.txt".format(strain=wildcards.strain)).read().strip()) * config["filtlong"]["target_base_multiplier"]
    shell:
        """
        mkdir -p {output[0].parent}
        filtlong --target_bases {params.keep_bases} --min_length {config[filtlong].min_length} --keep_percent {config[filtlong].keep_percent} {input.reads} > {output}
        """

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
        flye --nano-hq {input} --out-dir {output[0].parent} --threads {threads} {config[flye].extra}
        """

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
        "base"
    shell:
        """
        mkdir -p {output[0].parent}
        {config[pgap][pgap_path]} --taxcheck-only -g {input} --output {output[0].parent} -s 'bacterium sp.' -c {threads} -n
        """

rule parse_taxcheck:
    input:
        "results/005_taxcheck/{strain}/ani-tax-report.txt"
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
        "base"
    params:
        species_name=lambda wildcards: open("results/005_taxcheck/{strain}/species_name.txt".format(strain=wildcards.strain)).read().strip()
    shell:
        """
        mkdir -p {output}
        {config[pgap][pgap_path]} -c {threads} -o {output} -s '{params.species_name}' -g {input.fasta} -n 
        """
