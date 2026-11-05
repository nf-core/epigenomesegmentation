#!/usr/bin/env bash

# Exit immediately if a command fails, an undefined variable is used, or a pipeline fails
set -euo pipefail

# ==========================================
# Variable Initialization
# ==========================================
YAML=""
JSON=""
SEG_DIR=""
OUTPUT=""
THREADS=""

show_help(){
    cat <<'HELP'
Usage: $(basename "$0") [OPTIONS]

Options for making plots and Markdown reports:
    -y, --yaml      YAML configuration file
    -j, --json      JSON file for model
    -s, --seg-dir   Directory containing tab and BED segmentation files
    -o, --output    Base name for output files and directory
    -@, --threads   Number of threads to use
    -h, --help      Show this help message and exit
HELP
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
        -s|--seg-dir)
            SEG_DIR="$2"
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

if [[ -z "${YAML}" || -z "${JSON}" || -z "${SEG_DIR}" || -z "${OUTPUT}" ]]; then
    echo "Error: --yaml, --json, --seg-dir, and --output are required." >&2
    show_help
    exit 1
fi
if [[ ! -d "${SEG_DIR}" ]]; then
    echo "Error: Segmentation directory '${SEG_DIR}' does not exist." >&2
    exit 1
fi

# ==========================================
# Main Execution
# ==========================================
OUT_DIR="Plots"
shopt -s nullglob
BED_FILES=("${SEG_DIR}"/viterbi_*.bed.gz)
if [[ ${#BED_FILES[@]} -eq 0 ]]; then
    echo "Error: No viterbi_*.bed.gz files found in '${SEG_DIR}'." >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

plot_statistics.py \
    -d "${YAML}" \
    -p "${OUT_DIR}/${OUTPUT}-histogram.png" \
    -c "${OUT_DIR}/${OUTPUT}-correlation.png" \
    -m "${OUT_DIR}/${OUTPUT}-methylation-density.png"

for BED in "${BED_FILES[@]}"; do
    filename=$(basename "${BED}")
    sample_id=${filename#viterbi_}
    sample_id=${sample_id%.bed.gz}
    TAB="${SEG_DIR}/${sample_id}.tab"
    if [[ ! -f "${TAB}" ]]; then
        echo "Error: Expected tab file '${TAB}' for BED file '${BED}'." >&2
        exit 1
    fi

    PREFIX="${sample_id}"

    results.py \
        -c "${TAB}" \
        -j "${JSON}" \
        -e "${OUT_DIR}/${PREFIX}-meanEmission-viterbi.png" \
        -t "${OUT_DIR}/${PREFIX}-transitionMatrix.png" \
        -m "${OUT_DIR}/${PREFIX}-stateMembership-viterbi.png" \
        -l "${OUT_DIR}/${PREFIX}-stateLength-viterbi.png" \
        -s viterbi \
        -n "${OUT_DIR}/${PREFIX}-normEmission-viterbi.png" \
        -d "${BED}"

    plot_state_histograms.py \
        -c "${TAB}" \
        -j "${JSON}" \
        -a "${OUT_DIR}/${PREFIX}-stateDistribution.png" \
        -s viterbi

    plot_state_colors.py \
        -d "${BED}" \
        -o "${OUT_DIR}/${PREFIX}-state-colors.png"

    segmentation_report_dm_md.sh \
        -n "${PREFIX}" \
        -o "${OUT_DIR}" \
        -p "${OUTPUT}"
done

echo "Plots and Markdown reports generated successfully in ${OUT_DIR}/"
