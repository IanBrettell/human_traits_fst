#rule download_1KG_38_annotated:
#    params:
#        input = os.path.join(config["ftp_dir_1kg_38_annotated"], "ALL.chr{chr}.phase3_shapeit2_mvncall_integrated_v3plus_nounphased.rsID.genotypes.GRCh38_dbSNP.vcf{gz_ext}")
#    output:
#        os.path.join(config["working_dir"], "vcfs/1kg/20150319/chrs/{chr}.vcf{gz_ext}")
#    log:
#        os.path.join(config["log_dir"], "download_1KG_38_annotated/{chr}_{gz_ext}.log")
#    container:
#        config["bash"]
#    shell:
#        """
#        wget -O {output} {params.input} \
#            2> {log}
#        """

rule download_1KG_38_highcov:
    params:
        input = os.path.join(config["ftp_dir_1kg_38_highcov"], "CCDG_14151_B01_GRM_WGS_2020-08-05_chr{chr}.filtered.shapeit2-duohmm-phased.vcf.gz")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/chrs/{chr}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "download_1KG_38_highcov/{chr}.log")
    container:
        config["bash"]
    shell:
        """
        wget -O {output} {params.input} \
            2> {log}
        """

rule index_highcov:
    input:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/chrs/{chr}.vcf.gz")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/chrs/{chr}.vcf.gz.tbi")
    log:
        os.path.join(config["log_dir"], "index_highcov/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools index \
            --tbi \
            {input} \
                2> {log}
        """

rule download_dbsnp:
    params:
        input = config["dbsnp_vcf_prefix"] + "{gz_ext}"
    output:
        os.path.join(config["working_dir"], "vcfs/dbsnp/20180424/dbsnp.vcf{gz_ext}")
    log:
        os.path.join(config["log_dir"], "download_dbsnp/all_{gz_ext}.log")
    container:
        config["bash"]
    shell:
        """
        wget -O {output} {params.input} \
            2> {log}
        """

# It appears we need to remove the existing annotations before adding them from dbsnp ¯\_(ツ)_/¯ 
rule remove_annotations:
    input:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/chrs/{chr}.vcf.gz")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "remove_annotations/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools annotate \
            --remove ID \
            --output {output} \
            --output-type z \
            {input} \
                2> {log}
        """    

# And then index them before annotating them again, ugh
rule index_no_annotations:
    input:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz.tbi")
    log:
        os.path.join(config["log_dir"], "index_no_annotations/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools index \
            --tbi \
            {input} \
                2> {log}
        """

# Doesn't work
#rule annotate_highcov:
#    input:
#        vcf_1kg = os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz"),
#        tbi_1kg = os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz.tbi"),
#        dbsnp = os.path.join(config["working_dir"], "vcfs/dbsnp/20180424/dbsnp.vcf.gz")
#    output:
#        os.path.join(config["working_dir"], "vcfs/1kg/20201028/annotated/{chr}.vcf.gz")
#    log:
#        os.path.join(config["log_dir"], "annotate_highcov/{chr}.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools annotate \
#            --annotations {input.dbsnp} \
#            --columns ID \
#            --output {output} \
#            --output-type z \
#            {input.vcf_1kg} \
#                2> {log}
#        """

rule annotate_highcov:
    input:
        vcf_1kg = os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz"),
        tbi_1kg = os.path.join(config["working_dir"], "vcfs/1kg/20201028/no_annotations/{chr}.vcf.gz.tbi"),
        dbsnp = os.path.join(config["working_dir"], "vcfs/dbsnp/20180424/dbsnp.vcf.gz")
    output:
        os.path.join(config["working_dir"], "vcfs/1kg/20201028/annotated/{chr}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "annotate_highcov/{chr}.log")
    container:
        config["snpsift"]
    shell:
        """
        SnpSift Annotate \
            -id \
            {input.dbsnp} \
            {input.vcf_1kg} \
                > {output} \
                    2> {log}
        """

# Filter for 2504 unrelated samples.
# Note: this command requires `--output-file` instead of `--output`
rule filter_highcov_samples:
    input:
        vcf = os.path.join(config["working_dir"], "vcfs/1kg/20201028/annotated/{chr}.vcf.gz"),
        samples = config["1kgp_2504_samples"]
    output:
        os.path.join(config["lts_dir"], "vcfs/1kg/20201028/2504_samples/{chr}.vcf.gz")
    log:
        os.path.join(config["log_dir"], "filter_highcov_samples/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools view \
            --samples-file {input.samples} \
            --output-file {output} \
            --output-type z \
            {input.vcf} \
                2> {log}
        """        

# When trying to merge, get the following error:
#Caused by: htsjdk.tribble.TribbleException$InvalidHeader: Your input file has a malformed header: Unclosed quote in header line value <ID=ssID,Number=A,Type=String,Description=dbSNP ssID of the allele">
# Therefore created a new header file with:
# bcftools view /hps/nobackup/birney/users/ian/hmn_fst/vcfs/1kg/20150319/chrs/1.vcf.gz | grep "#" > /hps/nobackup/birney/users/ian/hmn_fst/vcfs/1kg/20150319/new_header.vcf
# Then manually inserted the missing quote. Use that file to re-header all VCFs before merging

#rule fix_vcf_headers:
#    input:
#        os.path.join(config["working_dir"], "vcfs/1kg/20150319/chrs/{chr}.vcf.gz")
#    output:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/reheaded/{chr}.vcf.gz")
#    log:
#        os.path.join(config["log_dir"], "fix_vcf_headers/{chr}.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools reheader \
#            --header {config[new_header]} \
#            --output {output} \
#            {input}
#        """

#rule index_vcfs:
#    input:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/reheaded/{chr}.vcf.gz")
#    output:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/reheaded/{chr}.vcf.gz.tbi")
#    log:
#        os.path.join(config["log_dir"], "index_vcfs/{chr}.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools index \
#            --tbi \
#            {input}
#        """

rule index_vcfs:
    input:
        os.path.join(config["lts_dir"], "vcfs/1kg/20201028/2504_samples/{chr}.vcf.gz")
    output:
        os.path.join(config["lts_dir"], "vcfs/1kg/20201028/2504_samples/{chr}.vcf.gz.tbi")
    log:
        os.path.join(config["log_dir"], "index_vcfs/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools index \
            --tbi \
            {input}
        """

#rule concat_vcfs:
#    input:
#        expand(os.path.join(config["lts_dir"], "vcfs/1kg/20150319/reheaded/{chr}.vcf.gz"),
#                chr = CHRS
#        )
#    output:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/all/all.vcf.gz")
#    log:
#        os.path.join(config["log_dir"], "concat_vcfs/all.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools concat \
#            --output {output} \
#            --output-type z \
#            {input}
#        """

#rule index_full_vcf:
#    input:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/all/all.vcf.gz")
#    output:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/all/all.vcf.gz.tbi")
#    log:
#        os.path.join(config["log_dir"], "index_full_vcf/all.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools index \
#            --tbi \
#            {input}
#        """

# Get minor allele frequencies of all variants in VCF    
#rule get_mafs:
#    input:
#        os.path.join(config["lts_dir"], "vcfs/1kg/20150319/reheaded/{chr}.vcf.gz")
#    output:
#        os.path.join(config["lts_dir"], "mafs/1kg/20150319/by_chr/{chr}.csv")
#    log:
#        os.path.join(config["log_dir"], "get_mafs/{chr}.log")
#    container:
#        config["bcftools"]
#    shell:
#        """
#        bcftools view \
#            --max-alleles 2 \
#            --output-type u \
#            {input} |\
#        bcftools query \
#            --format '%CHROM,%POS,%ID,%REF,%ALT,%EAS_AF,%AMR_AF,%AFR_AF,%EUR_AF,%SAS_AF\\n' \
#            --output {output} \
#                2> {log}
#        """

rule get_mafs:
    input:
        os.path.join(config["lts_dir"], "vcfs/1kg/20201028/2504_samples/{chr}.vcf.gz")
    output:
        os.path.join(config["lts_dir"], "mafs/1kg/20201028/by_chr/{chr}.csv")
    log:
        os.path.join(config["log_dir"], "get_mafs/{chr}.log")
    container:
        config["bcftools"]
    shell:
        """
        bcftools view \
            --max-alleles 2 \
            --output-type u \
            {input} |\
        bcftools query \
            --format '%CHROM,%POS,%ID,%REF,%ALT,%AF_AFR,%AF_AMR,%AF_EAS,%AF_EUR,%AF_SAS\\n' \
            --output {output} \
                2> {log}
        """

#rule combine_mafs:
#    input:
#        expand(os.path.join(config["lts_dir"], "mafs/1kg/20150319/by_chr/{chr}.csv"),
#                chr = CHRS)
#    output:
#        os.path.join(config["lts_dir"], "mafs/1kg/20150319/all/all.csv")
#    log:
#        os.path.join(config["log_dir"], "combine_mafs/all.log")
#    params:
#        header = "'CHROM,POS,ID,REF,ALT,EAS_AF,AMR_AF,AFR_AF,EUR_AF,SAS_AF'"
#    container:
#        config["bash"]
#    shell:
#        """
#        echo {params.header} > {output} ;
#        cat {input} >> {output}
#        """

rule combine_mafs:
    input:
        expand(os.path.join(config["lts_dir"], "mafs/1kg/20201028/by_chr/{chr}.csv"),
                chr = CHRS)
    output:
        os.path.join(config["lts_dir"], "mafs/1kg/20201028/all/all.csv")
    log:
        os.path.join(config["log_dir"], "combine_mafs/all.log")
    params:
        header = "'CHROM,POS,ID,REF,ALT,AF_AFR,AF_AMR,AF_EAS,AF_EUR,AF_SAS'"
    container:
        config["bash"]
    shell:
        """
        echo {params.header} > {output} ;
        cat {input} >> {output}
        """

rule get_population_file:
    input:
        FTP.remote(config["ftp_pop_file"], keep_local = True)
    output:
        config["local_pop_file"]
    log:
        os.path.join(config["log_dir"], "get_population_file/all.log")
    run:
        pop_file = pd.read_excel(input[0], sheet_name = "Sample Info")
        pop_file = pop_file.loc[:, ['Sample', 'Population']]
        pop_file.to_csv(output[0], index = False)

rule get_population_file_plink:
    input:
        FTP.remote(config["ftp_pop_file"], keep_local = True)
    output:
        config["local_pop_file_plink"]
    log:
        os.path.join(config["log_dir"], "get_population_file_plink/all.log")
    run:
        pop_file = pd.read_excel(input[0], sheet_name = "Sample Info")
        pop_file = pop_file.loc[:, ['Sample', 'Population']]
        # Create second column of samples as IIDs
        pop_file['Sample_2'] = pop_file['Sample']
        # Rename columns
        pop_file = pop_file.rename(columns = {"Sample" : "FID", "Sample_2" : "IID", "Population" : "CLUSTER"})
        # Re-order columns
        pop_file = pop_file[['FID', 'IID', 'CLUSTER']]
        # Write to file
        pop_file.to_csv(output[0], sep = "\t", header = False, index = False)
