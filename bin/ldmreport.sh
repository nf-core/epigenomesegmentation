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

# ==========================================
# Argument Parsing
# ==========================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yaml) YAML="$2"; shift 2 ;;
        -j|--json) JSON="$2"; shift 2 ;;
        -s|--seg-dir) SEG_DIR="$2"; shift 2 ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        -@|--threads) THREADS="$2"; shift 2 ;;
        *) echo "Error: Unknown argument '$1'"; exit 1 ;;
    esac
done

# ==========================================
# Main Execution
# ==========================================
OUT_DIR="Plots"
mkdir -p "${OUT_DIR}"

# 1. Generate Global Statistics (Runs once for the whole joint model)
plot_statistics.py \
    -d "${YAML}" \
    -p "${OUT_DIR}/${OUTPUT}-histogram.png" \
    -c "${OUT_DIR}/${OUTPUT}-correlation.png" \
    -m "${OUT_DIR}/${OUTPUT}-methylation-density.png"

# 2. Loop over every sample's BED file
for BED in "${SEG_DIR}"/viterbi_*.bed.gz; do
    
    # Extract the pure sample ID (e.g., heart_E11.5_1)
    filename=$(basename "$BED")
    sample_id=${filename#viterbi_}
    sample_id=${sample_id%.bed.gz}

    # Define the corresponding TAB file path
    TAB="${SEG_DIR}/${sample_id}.tab"
    
    # Keep per-sample outputs named by the segmentation sample ID.
    PREFIX="${OUT_DIR}/${sample_id}"

    # Run the sample-specific plotting scripts
    results.py \
        -c "${TAB}" \
        -j "${JSON}" \
        -e "${PREFIX}-meanEmission.png" \
        -t "${PREFIX}-transitionMatrix.png" \
        -m "${PREFIX}-stateMembership.png" \
        -l "${PREFIX}-stateLength.png" \
        -s viterbi \
        -n "${PREFIX}-normEmission.png" \
        -d "${BED}"

    plot_state_histograms.py \
        -c "${TAB}" \
        -j "${JSON}" \
        -a "${PREFIX}-stateDistribution.png" \
        -l "${PREFIX}-statelengthDistribution.png" \
        -s viterbi

    plot_state_colors.py \
        -d "${BED}" \
        -o "${PREFIX}-state-colors.png"

    cp "${OUT_DIR}/${OUTPUT}-methylation-density.png" "${PREFIX}-methylation-density.png" 2>/dev/null || true

    segmentation_report_md.sh \
        -n "${sample_id}" \
        -o "${OUT_DIR}" \
        -p "${OUTPUT}"
done

echo "Plots and Markdown reports generated successfully in ${OUT_DIR}/"
