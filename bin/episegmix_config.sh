#!/usr/bin/env bash

# ==============================================================================
# Initialize Variables
# ==============================================================================
MARK=()
DISTRIBUTION_HISTONE=()
METH_MARK=()
DISTRIBUTION_DNA=()
STATE=""
HISTONE=""
WGBS=""
chr=""
output_file="config.yaml"

# ==============================================================================
# Parse Command-Line Arguments
# ==============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--distribution_histone) IFS=' ' read -r -a DISTRIBUTION_HISTONE <<< "$2"; shift 2 ;;
        -s|--state) STATE="$2"; shift 2 ;;
        -m|--mark) IFS=' ' read -r -a MARK <<< "$2"; shift 2 ;;
        -x|--meth_mark) IFS=' ' read -r -a METH_MARK <<< "$2"; shift 2 ;;
        -n|--distribution_dna) IFS=' ' read -r -a DISTRIBUTION_DNA <<< "$2"; shift 2 ;;
        -h|--histone) HISTONE="$2"; shift 2 ;;
        -g|--wgbs) WGBS="$2"; shift 2 ;;
        -c|--chr) chr="$2"; shift 2 ;;
        -o|--output) output_file="$2"; shift 2 ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ==============================================================================
# Deduplicate and Sort Histone Marks (keeping distributions in sync)
# ==============================================================================
declare -A seen_marks
declare -A mark_dist_map
UNIQUE_MARK=()

# 1. Deduplicate and map each mark to its corresponding distribution
for i in "${!MARK[@]}"; do
    mark="${MARK[$i]}"
    # Only process if the mark hasn't been seen yet
    if [[ -z "${seen_marks[$mark]}" ]]; then
        seen_marks[$mark]=1
        UNIQUE_MARK+=("$mark")
        mark_dist_map[$mark]="${DISTRIBUTION_HISTONE[$i]}"
    fi
done

# 2. Sort the unique marks alphabetically
# The mapfile command safely reads the sorted output into a new array
mapfile -t SORTED_MARKS < <(printf '%s\n' "${UNIQUE_MARK[@]}" | sort)

# 3. Rebuild original arrays in the newly sorted order
MARK=()
DISTRIBUTION_HISTONE=()
for mark in "${SORTED_MARKS[@]}"; do
    if [[ -n "$mark" ]]; then # Skip empty lines
        MARK+=("$mark")
        DISTRIBUTION_HISTONE+=("${mark_dist_map[$mark]}")
    fi
done

# ==============================================================================
# Output Configuration
# ==============================================================================
{
    echo "states: ${STATE:-8}"

    # 1. Histone Markers Section
    if [[ "${#MARK[@]}" -gt 0 && "${MARK[0]}" != "null" ]]; then
        echo "marker: ${#MARK[@]}"
        echo "marker_spec:"
        for i in "${!MARK[@]}"; do
            echo "  - name: ${MARK[$i]}"
            echo "    distribution: ${DISTRIBUTION_HISTONE[$i]:-NBI}"
        done
    fi

    # 2. Histone Data
    if [[ -n "${HISTONE}" && "${HISTONE}" != "null" ]]; then
        echo "data: [${HISTONE}]"
    fi

    # 3. DNA Methylation Section
    if [[ "${WGBS}" != "null" && -n "${WGBS}" ]]; then

        # Check if we have DNA marks
        if [[ "${#METH_MARK[@]}" -gt 0 ]]; then
            echo "coverage_marker: ${#METH_MARK[@]}"
            echo "coverage_marker_spec:"
            for i in "${!METH_MARK[@]}"; do
                # Get the corresponding distribution, default to null if missing
                echo "  - name: ${METH_MARK[$i]}"
                echo "    distribution: ${DISTRIBUTION_DNA[$i]:-BI}"
            done
        fi
        echo "coverage_data: [${WGBS}]"
    fi

    echo "chr: [${chr:-12}]"
} > "${output_file}"
