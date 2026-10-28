#!/bin/bash
script_name="counts.sh"
set -e
set -o pipefail

usage() {
  echo "Usage: $0 -t <input_sheet> -f <output_stem> -o <output_directory>"
  exit 1
}
timestamp() {
	  date +"%T"
}

printHelp() {
   echo -e "${bold}Description:${normal}"
   echo -e "This script generates a count matrix for ChIP-seq and/or WGBS/NOME methylation data."
   echo -e "Input is a tab-delimited samplesheet where the first column is the mark name and the"
   echo -e "second column is the path to the corresponding BAM or BED file. BAM files are used for"
   echo -e "histone mark counts; BED files (GEMBS output) are used for methylation counts."
   echo -e "Both types can be mixed in the same samplesheet."
   echo -e ""
   echo -e "${bold}Usage:${normal}"
   echo -e "bash $script_name  ${bold}$(tput setaf 1)-t Input sheet  -o output directory  -f output stem  [-b binsize] [-d input directory] [-p paired end] [-c cores] [-g genome] [-r regions] [-s shift]"
   echo -e ""
   echo -e "${bold}${red}Please give always absolute paths!${normal}"
   echo -e "${bold}Mandatory:$(tput sgr0)"
   echo -e "  -t Input sheet - two-column tab-separated file:"
   echo -e "		column 1: mark name (e.g. H3K4me3, WGBS, NOME)"
   echo -e "		column 2: path to BAM file (histone marks) or BED file (methylation)"
   echo -e "		* BAM and BED entries can be mixed in the same sheet."
   echo -e "		* Provide complete paths, or use -d to supply a directory prefix."
   echo -e "		* BAM entries with the same mark name are treated as replicates and merged."
   echo -e "  -f output file stem name used as prefix for all generated files."
   echo -e "  -o complete path to the output directory."
   echo -e "${bold}Optional:${normal}"
   echo -e "  -b binsize in base pairs. Default: 200"
   echo -e "  -d complete path to the directory containing input files."
   echo -e "		File names in the input sheet are appended to this path."
   echo -e "  -s basepairs to shift from 5' end when counting reads (single end only). Default: 75"
   echo -e "  -p paired-end mode. Default: ignore"
   echo -e "		ignore   - treat like single end"
   echo -e "		filter   - 5'-end of first read in a properly aligned pair"
   echo -e "		midpoint - consider the midpoint of an aligned fragment"
   echo -e "  -c number of cores for generating count matrices. Default: 4"
   echo -e "  -g genome assembly. When provided, chromosome sizes are downloaded automatically via"
   echo -e "		fetchChromSizes and used as the regions file (overrides -r if both given)."
   echo -e "		Example inputs:"
   echo -e "		mm10 - mouse genome version 10"
   echo -e "		hg19 - Human genome version 19 (Ensembl-37)"
   echo -e "		hg38 - Human genome version 38 (Ensembl-38)"
   echo -e "  -r regions file for creating the count matrix. Required when no BAM files are present"
   echo -e "		and -g is not provided. Contains three tab-separated columns:"
   echo -e "		first column  - chromosome name. Eg. chr1"
   echo -e "		second column - start position. Eg. 1"
   echo -e "		third column  - chromosome length in bp. Eg. 248956422"
   echo -e ""
   echo -e "${bold}Methylation BED files (GEMBS output):${normal}"
   echo -e "  Include BED entries in the input sheet alongside BAM entries."
   echo -e "  Both plain .bed and gzip-compressed .bed.gz files are accepted."
   echo -e "  Strand information is merged per CpG (col5=cov, col6=strand, col11=meth ratio)."
   echo -e "  Meth reads per CpG = min(int(ratio * cov), cov), summed across strands."
   echo -e "  Cov and Meth are averaged across all CpGs per bin."
   echo -e "  With BAM files: methylation columns appended to a separate _refined_counts_methyl.txt."
   echo -e "  Without BAM files: output is chr start end Cov Meth [Cov Meth ...] in _refined_counts.txt."
}

# -----------------------------------------------------------------------
# Merge strand-specific CpG methylation and compute per-bin Cov and Meth
# Arguments: input_bed  chr_window_bed  output_file
# -----------------------------------------------------------------------
process_methylation_bed() {
    local input=$1
    local chr_window=$2
    local output=$3

    local reader="cat"
    [[ "${input}" == *.gz ]] && reader="zcat"

    join -1 1 -2 1 -a 1 -a 2 \
      <(${reader} ${input} | awk -vOFS='\t' '($1~/^chr[1-9XY][0-9]$/ || $1~/^chr[1-9XY]$/ || $1~/^[1-9XY][0-9]$/ || $1~/^[1-9XY]$/) && $6=="+" {print $1"_"$2, $1, $2, $6, $5, $11}' | sort -k1,1) \
      <(${reader} ${input} | awk -vOFS='\t' '($1~/^chr[1-9XY][0-9]$/ || $1~/^chr[1-9XY]$/ || $1~/^[1-9XY][0-9]$/ || $1~/^[1-9XY]$/) && $6=="-" {print $1"_"($2-1), $1, $2-1, $6, $5, $11}' | sort -k1,1) \
    | sort -k2,2 -k3,3n \
    | awk -vOFS='\t' '{
        chr=$2; start=$3;
        cov_p=$5+0;  meth_p=$6+0;
        cov_m=$10+0; meth_m=$11+0;
        meth_reads_p=int(meth_p*cov_p);
        if (meth_reads_p > cov_p) meth_reads_p=int(cov_p);
        meth_reads_m=int(meth_m*cov_m);
        if (meth_reads_m > cov_m) meth_reads_m=int(cov_m);
        cov=cov_p+cov_m;
        meth=meth_reads_p+meth_reads_m;
        print chr, start, start+1, cov, meth
    }' \
    | bedtools map -a <(sort -k1,1 -k2,2n ${chr_window}) -b - -c 4,5 -o mean,mean -null 0 \
    | awk -vOFS='\t' '{c=$4+0; m=$5+0; if (m>c) m=c; print $1,$2,$3,int(c),int(m)}' \
    > ${output}
}

# default values
binsize=200
shift_bp=75
paired_end=ignore
cores=4

while getopts ":ht:o:c:b:s:p:f:d:g:r:" OPTION
do
        case $OPTION in
                h)
                        printHelp; exit 0 ;;
                t)
                        tab_file="$OPTARG" ;;
                o)
                        output_dir=$OPTARG ;;
                c)
                        cores=$OPTARG ;;
                b)
                        binsize=$OPTARG ;;
                s)
                        shift_bp=$OPTARG ;;
                p)
                        paired_end=$OPTARG ;;
                f)
                        filename=$OPTARG ;;
                d)
                        input_dir=$OPTARG ;;
                g)
                        genome=$OPTARG ;;
                r)
                        regions_chromosome=$OPTARG ;;
        esac
done

# Validate mandatory arguments
if [ -z "${tab_file}" ] || [ -z "${filename}" ] || [ -z "${output_dir}" ]; then
        echo "Error: -t, -f, and -o are all required."
        usage
fi

echo -e "${bold}${magenta}The following command was used:${normal} ${bold}bash $script_name" $@ ${normal}

# Output folder check if the user did not create the output folder than it would be created
if [ ! -d "${output_dir}" ]
	then
		mkdir -p "${output_dir}"
		echo -e "Output directory created: ${output_dir}"
	else
		echo -e "Output directory already exists; files may be overwritten: ${output_dir}"
fi

if [ -z "${genome}" ]
then
        output_file=$(realpath -s ${output_dir}/${filename})
else
        output_file=$(realpath -s ${output_dir}/${filename}_${genome})
fi

# If genome is provided and no regions_chromosome, download chromosome sizes from UCSC
genome_chrom_sizes_tmp=""
if [ -n "${genome}" ] && [ -z "${regions_chromosome}" ]; then
        echo -e "$(timestamp) Downloading chromosome sizes for ${genome}"
        genome_chrom_sizes_tmp=${output_file}_${genome}_chrom_sizes.bed
        fetchChromSizes ${genome} \
                | awk -vOFS='\t' '$1~/^chr[1-9XY][0-9]$/ || $1~/^chr[1-9XY]$/ || $1~/^[1-9XY][0-9]$/ || $1~/^[1-9XY]$/ {print $1, 1, $2}' \
                > ${genome_chrom_sizes_tmp}
        regions_chromosome=${genome_chrom_sizes_tmp}
        echo -e "$(timestamp) Chromosome sizes for ${genome} downloaded and saved as ${genome_chrom_sizes_tmp}"
fi

# Variable definitions for output files
counts_txt=${output_file}"_counts.txt"
refine_chr_regions=${output_file}"_refine_chr_regions.bed"
refine_regions=${output_file}".bed"
episegmix_input=${output_file}"_refined_counts.txt"

# if user provided input directory and paths of the bam file then create a new tab file
if [ -z "${input_dir}" ]
then
        echo -e "Input file to be used: ${tab_file}"
else
        while read marks files
        do
                path=$(realpath -s ${input_dir}/${files})
                echo -e "${marks}\t${path}"
        done < ${tab_file} > ${output_file}_episegmix_input.txt
        tab_file=$(realpath -s ${output_file}_episegmix_input.txt)
        echo -e "Input file to be used: ${tab_file}"
fi

# Split samplesheet into BAM and BED entries based on file extension
bam_tab=${output_file}_bam_input.txt
bed_tab=${output_file}_bed_input.txt
> ${bam_tab}
> ${bed_tab}
while read mark file; do
        if [[ "${file,,}" == *.bam ]]; then
                echo -e "${mark}\t${file}" >> ${bam_tab}
        elif [[ "${file,,}" == *.bed ]] || [[ "${file,,}" == *.bed.gz ]]; then
                echo -e "${mark}\t${file}" >> ${bed_tab}
        fi
done < ${tab_file}

has_bam=false
has_methyl=false
[ -s ${bam_tab} ] && has_bam=true
[ -s ${bed_tab} ] && has_methyl=true

if [ "${has_bam}" = true ]; then

        echo -e "$(timestamp) Checking for the input files"
        # 1. Check all the paths and index bam files
        bam_files=($(cut -f 2 ${bam_tab}))
        number_of_bams=${#bam_files[@]}
        j=0
        while [ "$j" -le "$((number_of_bams-1))" ]
                do
                        bamfile=${bam_files[$j]}
                        [ -f ${bamfile} ] || { echo "File '${bamfile}' not found."; exit 1; }
                        [ -f ${bamfile}.bai ] || { samtools index ${bamfile} ; }
                        j=$(($j + 1))
                done

        # 2. Create regions file if user did not provide
        echo -e "$(timestamp) Finalizing the regions for the count matrix"
        chrom_sizes_generated=false
        if [ -z "${regions_chromosome}" ]
        then
                samtools view -H ${bamfile} \
                        | grep "@SQ" \
                        | cut -f 2,3 \
                        | cut -d ":" -f 2,3 \
                        | awk -F"\t|:" '{print $1,$3}' \
                        | awk -vOFS='\t' '{print $1,1,$2}' \
                        | awk '$1~/^chr[1-9XY][0-9]$/ || $1~/^chr[1-9XY]$/ ||$1~/^[1-9XY][0-9]$/ || $1~/^[1-9XY]$/' \
                        > ${output_file}_chrom_sizes.bed
                chrom_sizes=${output_file}_chrom_sizes.bed
                chrom_sizes_generated=true
        else
                echo "user provided chromosome regions will be used for generating count matrices"
                chrom_sizes=${regions_chromosome}
        fi

        # 3. Run counts.R and generate the count matrix
        echo -e "$(timestamp) Reading bam files and generating count matrix"
        Rscript "$(dirname "$0")/counts.R" ${bam_tab} ${chrom_sizes} ${binsize} ${shift_bp} ${output_file} ${cores} ${paired_end}

        # 4. Create windows and EpiSegMix input
        bedtools makewindows -b ${refine_chr_regions} -w ${binsize} > ${refine_regions}

        paste <(awk -v OFS="\t" 'BEGIN{print "chr\tstart\tend"} {gsub(/^chr/,"",$1); print $1,$2,$3}' ${refine_regions}) \
                <(awk -vOFS="\t" '{print}' ${counts_txt}) \
                > ${episegmix_input}

        # 5. Process methylation counts if BED files present in samplesheet
        if [ "${has_methyl}" = true ]; then
                echo -e "$(timestamp) Processing methylation counts"
                i=0
                methyl_tmp_files=()
                while read mark mbed; do
                        [ -f "${mbed}" ] || { echo "Methylation BED file '${mbed}' not found."; exit 1; }
                        mbed_merged=${output_file}_methyl_merged_${i}.bed
                        mbed_tmp=${output_file}_methyl_tmp_${i}.txt
                        process_methylation_bed ${mbed} ${refine_regions} ${mbed_merged}
                        { printf "Cov\tMeth\n"
                          awk -vOFS="\t" '{print $4,$5}' ${mbed_merged}; } > ${mbed_tmp}
                        methyl_tmp_files+=("${mbed_tmp}")
                        rm ${mbed_merged}
                        i=$((i+1))
                done < ${bed_tab}
                methyl_episegmix_input=${output_file}_refined_counts_combined.txt
                methyl_only_input=${output_file}_refined_counts_methyl.txt
                paste ${episegmix_input} "${methyl_tmp_files[@]}" > ${methyl_episegmix_input}
                paste "${methyl_tmp_files[@]}" > ${methyl_only_input}
                rm "${methyl_tmp_files[@]}"
                echo -e "$(timestamp) Methylation counts appended and saved as ${methyl_episegmix_input}"
                echo -e "$(timestamp) Methylation-only counts saved as ${methyl_only_input}"
        fi

        # 6. Remove temporary files
        rm ${counts_txt} ${refine_chr_regions}
        [ "${chrom_sizes_generated}" = true ] && rm ${chrom_sizes}
        [ -n "${genome_chrom_sizes_tmp}" ] && rm -f ${genome_chrom_sizes_tmp}

        echo -e "$(timestamp) Count matrix generated and saved as ${episegmix_input}"

else

        # === NO-BAM CASE: methylation only ===
        if [ "${has_methyl}" = false ]; then
                echo "Error: no BAM or BED files found in the samplesheet"; exit 1
        fi
        if [ -z "${regions_chromosome}" ]; then
                echo "Error: -r regions_chromosome must be provided when no BAM files are present in the samplesheet"; exit 1
        fi

        echo -e "$(timestamp) No BAM files detected. Creating regions for methylation count matrix"

        # 1. Create refine_chr_regions from regions_chromosome (filter standard chromosomes)
        awk -vOFS="\t" '$1~/^chr[1-9XY][0-9]$/ || $1~/^chr[1-9XY]$/ || $1~/^[1-9XY][0-9]$/ || $1~/^[1-9XY]$/ {print}' \
                ${regions_chromosome} > ${refine_chr_regions}

        # 2. Create window BED using binsize
        bedtools makewindows -b ${refine_chr_regions} -w ${binsize} > ${refine_regions}

        # 3. Process each methylation BED file
        echo -e "$(timestamp) Processing methylation counts"
        i=0
        methyl_tmp_files=()
        while read mark mbed; do
                [ -f "${mbed}" ] || { echo "Methylation BED file '${mbed}' not found."; exit 1; }
                mbed_merged=${output_file}_methyl_merged_${i}.bed
                mbed_tmp=${output_file}_methyl_tmp_${i}.txt
                process_methylation_bed ${mbed} ${refine_regions} ${mbed_merged}
                { printf "Cov\tMeth\n"
                  awk -vOFS="\t" '{print $4,$5}' ${mbed_merged}; } > ${mbed_tmp}
                methyl_tmp_files+=("${mbed_tmp}")
                rm ${mbed_merged}
                i=$((i+1))
        done < ${bed_tab}

        # 4. Create final output: chr start end Cov Meth [Cov Meth ...]
        #    Strip chr prefix from coordinate column for consistent naming
        paste <(awk -vOFS="\t" 'BEGIN{print "chr\tstart\tend"} {gsub(/^chr/,"",$1); print $1,$2,$3}' ${refine_regions}) \
                "${methyl_tmp_files[@]}" > ${episegmix_input}

        rm "${methyl_tmp_files[@]}" ${refine_chr_regions}
        [ -n "${genome_chrom_sizes_tmp}" ] && rm ${genome_chrom_sizes_tmp}

        echo -e "$(timestamp) Methylation count matrix generated and saved as ${episegmix_input}"

fi

rm ${bam_tab} ${bed_tab}
