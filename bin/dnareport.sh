#!/usr/bin/env bash

# Exit immediately if a command fails, an undefined variable is used, or a pipeline fails
set -euo pipefail

# ==========================================
# Variable Initialization
# ==========================================
YAML=""
JSON=""
TAB=""
BED=""
OUTPUT=""
THREADS=""


# ==========================================
# Functions
# ==========================================
show_help(){
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options for making plots and HTML report:
    -y, --yaml      YAML configuration file
    -j, --json      JSON file for model
    -t, --tab       Tab-separated segmentation file
    -b, --bed       BED file of segmentation
    -o, --output    Base name for output files and directory
    -@, --threads   Number of threads to use
    -h, --help      Show this help message and exit
EOF
}

# ==========================================
# Argument Parsing
# ==========================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yaml)
            YAML="$2"
            shift 2
            ;;
        -j|--json)
            JSON="$2"
            shift 2
            ;;
        -t|--tab)
            TAB="$2"
            shift 2
            ;;
        -b|--bed)
            BED="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -@|--threads)
            THREADS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            show_help
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z "${YAML}" || -z "${OUTPUT}" || -z "${JSON}" ]]; then
    echo "Error: Missing required arguments (--yaml and --output and --json are required)." >&2
    show_help
    exit 1
fi

# ==========================================
# Main Execution
# ==========================================
OUT_DIR="Plots"
mkdir -p "${OUT_DIR}"

results.py \
    -c "${TAB}" \
    -j "${JSON}" \
    -e "${OUT_DIR}/${OUTPUT}-meanEmission.png" \
    -t "${OUT_DIR}/${OUTPUT}-transitionMatrix.png" \
    -m "${OUT_DIR}/${OUTPUT}-stateMembership.png" \
    -l "${OUT_DIR}/${OUTPUT}-stateLength.png" \
    -s viterbi \
    -n "${OUT_DIR}/${OUTPUT}-normEmission.png" \
    -d "${BED}"

plot_state_colors.py \
        -d "${BED}" \
        -o "${OUT_DIR}/${OUTPUT}-stateColors.png"

segmentation_report_meth.sh  \
        -n "${OUTPUT}" \
        -o "${OUT_DIR}/"

echo "Plots generated successfully in ${OUT_DIR}/"
