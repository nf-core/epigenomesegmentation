#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage: $0 -o PREFIX -b SHEETBAM -g GENOME -c CHROMSIZES [-s BINSIZE] [-@ THREADS]"
    exit 1
}

cpus=1
prefix=""
sheetbam=""
genome=""
chromsizes=""
binsize=200

# Parse arguments
while getopts "o:b:@:g:c:s:" opt; do
    case "$opt" in
        o) prefix="$OPTARG" ;;
        b) sheetbam="$OPTARG" ;;
        @) cpus="$OPTARG" ;;
        g) genome="$OPTARG" ;;
        c) chromsizes="$OPTARG" ;;
        s) binsize="$OPTARG" ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
[[ -n "$prefix" ]] || usage
[[ -n "$sheetbam" ]] || usage
[[ -n "$genome" ]] || usage
[[ -n "$chromsizes" ]] || usage

# Split the input sheet based on column 3 (true/false)
awk '{print $0 > ($3 ".txt")}' "${sheetbam}"

# Process Single-End (false)
if [ -f false.txt ]; then
    awk -v OFS="\t" '{print $1, $2}' false.txt > tmp && mv tmp false.txt
    counts.sh -t false.txt -o ./ -c "${cpus}" -p ignore -f "${prefix}_SE" -g "$genome" -r "$chromsizes" -b "$binsize"
fi

# Process Paired-End (true)
if [ -f true.txt ]; then
    awk -v OFS="\t" '{print $1, $2}' true.txt > tmp && mv tmp true.txt
    counts.sh -t true.txt -o ./ -c "${cpus}" -p midpoint -f "${prefix}_PE" -g "$genome" -r "$chromsizes" -b "$binsize"
fi

# --- DEFINE EXACT FILE NAMES BASED ON YOUR SCHEME ---
SE_FILE="${prefix}_SE_${genome}_refined_counts.txt"
PE_FILE="${prefix}_PE_${genome}_refined_counts.txt"
FINAL_OUT="${prefix}.tab"

# --- 1. DYNAMIC MERGE LOGIC ---

if [[ -f "$SE_FILE" ]] && [[ -f "$PE_FILE" ]]; then
    
    # 1. Extract and combine the headers directly into FINAL_OUT
    paste <(head -n 1 "$SE_FILE") <(head -n 1 "$PE_FILE" | cut -f4-) > "$FINAL_OUT"

    # 2. Get the number of columns in the SE file dynamically
    SE_COLS=$(awk -F'\t' '{print NF; exit}' "$SE_FILE")

    # 3. Intersect the data (using tail -n +2 to skip headers) and append (>>) to FINAL_OUT
    bedtools intersect -a <(tail -n +2 "$SE_FILE") -b <(tail -n +2 "$PE_FILE") -wa -wb -f 1.0 -r | \
        awk -v se="$SE_COLS" 'BEGIN{FS="\t"; OFS="\t"} {
            # Keep all columns from SE_FILE
            line = $1
            for (i=2; i<=se; i++) {
                line = line OFS $i
            }
            # Append columns from PE_FILE (skipping its 1st, 2nd, and 3rd cols: chr, start, end)
            for (i=se+4; i<=NF; i++) {
                line = line OFS $i
            }
            print line
        }' >> "$FINAL_OUT"

    # 4. Clean up
    rm -f "$SE_FILE" "$PE_FILE"

elif [[ -f "$SE_FILE" ]]; then
    # Only Single-End exists
    mv "$SE_FILE" "$FINAL_OUT"

elif [[ -f "$PE_FILE" ]]; then
    # Only Paired-End exists
    mv "$PE_FILE" "$FINAL_OUT"

else
    echo "Error: Neither SE nor PE count files were generated." >&2
    exit 1
fi

# --- 2. ALPHABETICAL SORT LOGIC (Cols 4+) ---

# Check how many columns the final file has
NUM_COLS=$(head -n 1 "$FINAL_OUT" | awk -F'\t' '{print NF}')

# Only attempt to sort if there are more than 3 columns
if [[ "$NUM_COLS" -gt 3 ]]; then

    # Figure out the alphabetical order of the headers (from col 4 onward)
    SORT_ORDER=$(head -n 1 "$FINAL_OUT" | cut -f4- | tr '\t' '\n' | cat -n | sort -k2,2 | awk '{print $1 + 3}' | paste -sd, -)

    # Rebuild the file using that specific order
    awk -v cols="1,2,3,${SORT_ORDER}" '
    BEGIN {
        FS = OFS = "\t"
        num_cols = split(cols, order, ",")
    }
    {
        for(i=1; i<=num_cols; i++) {
            printf "%s%s", $order[i], (i==num_cols ? ORS : OFS)
        }
    }' "$FINAL_OUT" > tmp_sorted.tab

    # Replace the unsorted file with the sorted one
    mv tmp_sorted.tab "$FINAL_OUT"
fi

# Clean up intermediate text files
rm -f false.txt true.txt
