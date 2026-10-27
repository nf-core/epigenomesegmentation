#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

usage() {
    echo "Usage: $0 -s SAMPLE_ID -m MODALITY -o OUTPUT_FILE -i INPUT_BED [-@ THREADS]"
    exit 1
}

# Default variables
cpus=1
sample_id=""
modality=""
output_file=""
file_path=""

# Parse Nextflow flags
while getopts "s:m:o:@:i:" opt; do
    case "$opt" in
        s) sample_id="$OPTARG" ;;
        m) modality="$OPTARG" ;;
        o) output_file="$OPTARG" ;;
        @) cpus="$OPTARG" ;;
        i) file_path="$OPTARG" ;;
        *) usage ;;
    esac
done

# Ensure all required parameters were provided
[[ -n "$sample_id" ]] || usage
[[ -n "$modality" ]] || usage
[[ -n "$output_file" ]] || usage
[[ -n "$file_path" ]] || usage

# Handle compressed vs uncompressed files
READ_CMD="cat"
if [[ "${file_path}" == *.gz ]]; then
    READ_CMD="zcat"
fi

# Process the data
{
    join -1 1 -2 1 -a 1 -a 2 \
        <( ${READ_CMD} "${file_path}" \
            | awk -v OFS='\t' '$6=="+" {print $1"_"$2, $1, $2, $6, $10, ($11*$10)/100}' \
            | sort --parallel="${cpus}" -k1,1 ) \
        <( ${READ_CMD} "${file_path}" \
            | awk -v OFS='\t' '$6=="-" {print $1"_"($2-1), $1, ($2-1), $6, $10, ($11*$10)/100}' \
            | sort --parallel="${cpus}" -k1,1 ) \
    | sort --parallel="${cpus}" -k2,2V -k3,3n \
    | awk -v OFS='\t' '{
            sub(/^chr/, "", $2);
	     printf ("%s\t%d\t%d\t%d\t%d\n", $2, $3, $3+1, $5+$10, ($6+$11)+0.5)
        }' \
    | grep -E -v "random|GL|NC|M|hs|hap|Un|J|EBV|ph|L"

} > "${output_file}"
