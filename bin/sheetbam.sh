#!/bin/bash

set -euo pipefail

bam_files=""
histone_marks=""
output_file=""
paired_end=""

print_usage() {
    echo "Usage: $0 -b \"bam1.bam bam2.bam\" -h \"[mark1, mark2]\" -p \"[paired, single]\" -o output"
    exit 1
}

while getopts "b:h:o:p:" flag; do
    case "${flag}" in
        b) bam_files="${OPTARG}" ;;
        h) histone_marks="${OPTARG}" ;;
        p) paired_end="${OPTARG}" ;;
        o) output_file="${OPTARG}" ;;
        *) print_usage ;;
    esac
done

# Check required arguments
if [[ -z "$bam_files" || -z "$histone_marks" || -z "$output_file" || -z "$paired_end" ]]; then
    print_usage
fi

# Convert BAM files string into an array
read -ra bam_array <<< "$bam_files"

# Remove surrounding brackets from paired end
paired_end="${paired_end#[}"
paired_end="${paired_end%]}"

# Remove surrounding brackets from histone marks
histone_marks="${histone_marks#[}"
histone_marks="${histone_marks%]}"

# Convert comma-separated histone marks into an array
IFS=',' read -ra mark_array <<< "$histone_marks"

# Convert comma-separated paired/single end into an array
IFS=',' read -ra paired_array <<< "$paired_end"

for i in "${!mark_array[@]}"; do
    mark_array[$i]=$(echo "${mark_array[$i]}" | xargs)
done

for i in "${!paired_array[@]}"; do
    paired_array[$i]=$(echo "${paired_array[$i]}" | xargs)
done

# Check lengths match
if [[ ${#bam_array[@]} -ne ${#mark_array[@]} || ${#bam_array[@]} -ne ${#paired_array[@]} ]]; then
    echo "Error: Number of BAM files (${#bam_array[@]}) does not match number of histone marks (${#mark_array[@]}) or paired end status (${#paired_array[@]})." >&2
    exit 1
fi

# Create/overwrite output file
: > "${output_file}"

# Write BAM ↔ histone mark pairs
for i in "${!bam_array[@]}"; do
    echo -e "${mark_array[$i]}\t${bam_array[$i]}\t${paired_array[$i]}" >> "${output_file}"
done

echo "Output written to ${output_file}"
