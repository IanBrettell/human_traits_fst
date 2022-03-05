
#rule get_all_associations:
#    input:
#        config["all_trait_ids_file"]
#    output:
#        os.path.join(config["lts_dir"], "gwasrapidd/{date}/associations_raw/{efo_id}.rds")
#    params:
#        output_dir = lambda wildcards, output: os.path.dirname(str(output[0]))
#    container:
#        config["R"]
#    script:
#        "../scripts/get_all_associations.R"
#
#rule get_associations:
#    output:
#        "data/gwasrapidd/{date}/associations_raw/{efo_id}.rds"
#    params:
#        date = lambda wildcards: wildcards.date,
#        efo_id = lambda wildcards: wildcards.efo_id,
#        output_dir = lambda wildcards, output: os.path.dirname(str(output))
#    container:
#        config["R"]
#    script:
#        "../scripts/get_associations.R"

#rule get_all_studies:
#    input:
#        expand(config["lts_dir"], "gwasrapidd/{date}/associations_raw/{efo_id}.rds")
#    output:
#        expand(config["lts_dir"], "gwasrapidd/{date}/studies_raw/{efo_id}.rds")

#rule get_studies:
#    input:
#        os.path.join(config["lts_dir"], "gwasrapidd/{date}/associations_raw/{efo_id}.rds")
#    output:
#        key = "data/gwasrapidd/{date}/studies_key/{efo_id}.rds",
#        studies = "data/gwasrapidd/{date}/studies_raw/{efo_id}.rds"
#    log:
#        os.path.join(config["log_dir"], "get_studies/{date}_{efo_id}.log")
#    container:
#        config["R"]
#    script:
#        "../scripts/get_studies.R"

# Pull SNP IDs from gwasrapidd results
rule get_snp_ids:
    input:
        os.path.join(config["lts_dir"], "gwasrapidd/{date}/associations_raw/{efo_id}.rds")
    output:
        os.path.join(config["lts_dir"], "gwasrapidd/{date}/associations_snp_ids/{efo_id}.txt")
    log:
        os.path.join(config["log_dir"], "get_snp_ids/{date}/{efo_id}.log")
    container:
        config["R"]
    script:
        "../scripts/get_snp_ids.R"

# Extract the genotypes from the 1KGP data for each SNP associated with each trait
# Run on each chromosome separately for speed
rule extract_gtypes:
    input:
        vcf = os.path.join(config["lts_dir"], "vcfs/1kg/20201028/2504_samples/{chr}.vcf.gz"),
        snps = os.path.join(config["lts_dir"], "gwasrapidd/{date}/associations_snp_ids/{efo_id}.txt")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/filtered/{date}/{efo_id}/by_chr/{chr}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "extract_gtypes/{date}/{efo_id}/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools view \
            --max-alleles 2 \
            --include ID=@{input.snps} \
            --output-type z \
            --output-file {output} \
            {input.vcf}
        """

# Merge chromosome VCFs into single VCF for each trait
rule merge_gtypes:
    input:
        expand(os.path.join(config["working_dir"], "vcfs/1kg/20201028/filtered/{{date}}/{{efo_id}}/by_chr/{chr}.vcf.gz"),
            chr = CHRS)
    output:
        vcf = os.path.join(config["lts_dir"], "gwasrapidd/{date}/high_cov/vcfs/original/{efo_id}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "merge_gtypes/{date}/{efo_id}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools concat \
            --output {output.vcf} \
            --output-type z \
            {input}
        """

# Remove duplicated variants to avoid problems downstream with Plink1.9
rule get_duplicated_sites:
    input:
        vcf = os.path.join(config["lts_dir"], "gwasrapidd/{date}/high_cov/vcfs/original/{efo_id}.vcf.gz")
    output:
        dup_sites = os.path.join(config["lts_dir"], "gwasrapidd/{date}/high_cov/dup_sites/{efo_id}.txt"),
        vcf = os.path.join(config["lts_dir"], "gwasrapidd/{date}/high_cov/vcfs/no_dups/{efo_id}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "get_duplicated_sites/{date}/{efo_id}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools view {input.vcf} | grep -v '^#' | cut -f 3 | sort | uniq -d > {output.dup_sites} ;
        bcftools view \
            --exclude ID=@{output.dup_sites} \
            --output-type z \
            --output-file {output.vcf} \
            {input.vcf}
        """