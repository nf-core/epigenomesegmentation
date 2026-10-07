#!/bin/bash

INPUT_CSV=""
OUTPUT_CSV=""
THREADS=1
TSV_OUTPUT="all_parsed_loglikelihoods.tsv"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input)
      INPUT_CSV="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_CSV="$2"
      shift 2
      ;;
    -@|--threads)
      THREADS="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./update_design.sh -i <input.csv> -o <output.csv> [-@ threads]"
      exit 0
      ;;
    *)
      echo "Error: Unknown parameter passed: $1"
      echo "Usage: ./update_design.sh -i <input.csv> -o <output.csv> [-@ threads]"
      exit 1
      ;;
  esac
done

if [[ -z "$INPUT_CSV" || -z "$OUTPUT_CSV" ]]; then
    echo "Error: Both input (-i) and output (-o) files are required."
    exit 1
fi

if [[ ! -f "$INPUT_CSV" ]]; then
    echo "Error: Input file '$INPUT_CSV' not found!"
    exit 1
fi

echo "Starting run with $THREADS thread(s)..."
echo "Parsing log files to extract log-likelihood..."

declare -A best_score
declare -A best_dist

TMP_SCORES=$(mktemp)

# 1. Loop through all log files
for log_file in *.log; do
    [ -e "$log_file" ] || continue

    basename="${log_file%.log}"
    IFS='_' read -r -a parts <<< "$basename"

    mark="${parts[-1]}"
    states="${parts[-2]}"
    dist="${parts[-3]}"

    suffix="_${dist}_${states}_${mark}"
    sample_id="${basename%$suffix}"

    key="${sample_id}_${mark}"

    # Extract Log-Likelihood
    score=$(tail -n 3 "$log_file" | head -n 1 | awk '{print $NF}' | tr -d '[:space:]')

    printf "%s\t%s\t%s\t%s\t%s\n" "$sample_id" "$mark" "$dist" "$states" "$score" >> "$TMP_SCORES"

    # Maximize the log-likelihood
    if [[ -z "${best_score[$key]}" ]]; then
        best_score[$key]="$score"
        best_dist[$key]="$dist"
    else
        is_greater=$(awk -v s1="$score" -v s2="${best_score[$key]}" 'BEGIN { print (s1 > s2) ? 1 : 0 }')
        if [[ "$is_greater" -eq 1 ]]; then
            best_score[$key]="$score"
            best_dist[$key]="$dist"
        fi
    fi
done

# 2. Sort temporary scores
echo "Generating sorted TSV of all log-likelihoods: $TSV_OUTPUT"
printf "Sample_ID\tMark\tDistribution\tStates\tLog_Likelihood\n" > "$TSV_OUTPUT"
sort -t$'\t' -k1,1 -k2,2 -k5,5gr "$TMP_SCORES" >> "$TSV_OUTPUT"
rm -f "$TMP_SCORES"

echo "Found best distributions. Updating CSV..."

# 3. Read the original CSV and write the new one
{
    # The || [[ -n "$sample_id" ]] ensures we don't drop the last row if it lacks a newline!
    while IFS=',' read -r sample_id replicate mark file_name modality paired_end distribution || [[ -n "$sample_id" ]]; do

        # Clean hidden carriage returns from Windows files
        distribution=$(echo "$distribution" | tr -d '\r')

        # Print the header line exactly as-is
        if [[ "$sample_id" == "sample_id" ]]; then
            echo "${sample_id},${replicate},${mark},${file_name},${modality},${paired_end},${distribution}"
            continue
        fi

        csv_key="${sample_id}_${mark}"
        final_dist="${distribution}"

        # If this is a BAM file and we found a better distribution, update it
        if [[ -n "${best_dist[$csv_key]}" ]]; then
            final_dist="${best_dist[$csv_key]}"
        fi

        # Output the row (If it's a BED file, it will just print the original final_dist!)
        echo "${sample_id},${replicate},${mark},${file_name},${modality},${paired_end},${final_dist}"

    done
} < "$INPUT_CSV" > "$OUTPUT_CSV"

echo "Done! CSV saved to $OUTPUT_CSV"
