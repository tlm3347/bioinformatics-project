include: "0_download_rnaseq_data.smk"

import os
from snakemake.remote.HTTP import RemoteProvider
HTTP = RemoteProvider()
reference_genome_url_prefix = "http://labshare.cshl.edu/shares/gingeraslab/www-data/dobin/STAR/STARgenomes/Human/GRCh38_Ensembl99_sparseD3_sjdbOverhang99"

rule download_genome:
    input:
        [HTTP.remote(f"{reference_genome_url_prefix}/{f}", keep_local=True)
         for f in ['chrLength.txt', 'chrName.txt', 'chrStart.txt', 'Genome',
                   'genomeParameters.txt', 'SA', 'SAindex', "sjdbInfo.txt"]]
    output:
        directory("../data/raw/reference_genome"),
        completion_flag=touch("../data/raw/reference_genome/download_genome.done")
    run:
        for f in input:
            shell("mv {f} {output[0]}")

rule star_double_ended:
    input:
        rules.download_genome.output["completion_flag"],
        fq1 = [os.path.join("..", fp) for fp in config["sequence_files_R1"]],
        fq2 = [os.path.join("..", fp) for fp in config["sequence_files_R2"]],
        reference_genome_dir=rules.download_genome.output[0]
    output:
        "../data/interim/{sample}_nonhost_R1.fastq",
        "../data/interim/{sample}_nonhost_R2.fastq"
    params:
        workdir="../data/interim/{sample}_alignment_workdir"
    conda:
        "../envs/star.yaml"
    threads: 12
    shell:
        "mkdir -p {params.workdir} "
        "&& STAR"
        "  --runThreadN {threads} "
        "  --genomeDir {input.reference_genome_dir} "
        "  --readFilesIn {input.fq1} {input.fq2} "
        "  --outFileNamePrefix {params.workdir} "
        "  --outReadsUnmapped Fastx "
        "&& mv {params.workdir}/Unmapped.out.mate1 {output[0]} "
        "&& mv {params.workdir}/Unmapped.out.mate2 {output[1]} "
        ";  rm -rf {params.workdir}"