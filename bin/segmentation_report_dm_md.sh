#!/usr/bin/env bash

# Exit immediately if a command fails
set -euo pipefail

NAME=""
OUTPUT_DIR=""
STATISTICS_PREFIX=""

# ==========================================
# Argument Parsing
# ==========================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--statistics-prefix)
            STATISTICS_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") -n <name> -o <output_dir>"
            echo "Options:"
            echo "  -n, --name         Base prefix for the sample"
            echo "  -o, --output-dir   Directory where plots and report will be saved"
            echo "  -p, --statistics-prefix  Prefix for shared model-level plots"
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${NAME}" || -z "${OUTPUT_DIR}" || -z "${STATISTICS_PREFIX}" ]]; then
    echo "Error: Missing required arguments (-n, -o, and -p)." >&2
    exit 1
fi

# ==========================================
# Generate Markdown
# ==========================================
mkdir -p "${OUTPUT_DIR}"
MD_FILE="${OUTPUT_DIR}/${NAME}_report.md"

cat <<EOF > "${MD_FILE}"
# EpiSegMix DM Segmentation Report
**Sample / Prefix ID:** ${NAME}

---

## 1. Emission & Transition Parameters

### Normalized Emission Probabilities
*Displays the scaled emission probabilities that define each hidden state.*
![Normalized Emission](./${NAME}-normEmission-viterbi.png)

### Mean Emission
*Shows the raw average signal intensity for each epigenetic mark within each state.*
![Mean Emission](./${NAME}-meanEmission-viterbi.png)

### Transition Matrix
*Shows the probability of transitioning from one hidden state to another along the chromosome.*
![Transition Matrix](./${NAME}-transitionMatrix.png)

---

## 2. Segmentation Overview

### State Colors
*The assigned color palette for each state, designed for visual tracking in genome browsers.*
![State Colors](./${NAME}-state-colors.png)

### State Membership & Coverage
*Illustrates the proportion of the genome assigned to each respective state.*
![State Membership](./${NAME}-stateMembership-viterbi.png)

---

## 3. Length & Distribution Characteristics

### Average State Length
*Displays the average genomic span (in base pairs) for contiguous segments of each state.*
![State Length](./${NAME}-stateLength-viterbi.png)

### State Distribution
*Shows the overall frequency and emission distribution for each chromatin state.*
![State Distribution](./${NAME}-stateDistribution.png)

---

## 4. Global Input Characteristics

### Marker Correlation
*Correlation matrix of the raw input markers to check for expected biological redundancies or batch effects.*
![Correlation](./${STATISTICS_PREFIX}-correlation.png)

### Signal Distributions
*Overall signal distribution across the input datasets used to train this model.*
![Histogram](./${STATISTICS_PREFIX}-histogram.png)
EOF

echo "Generated Markdown report: ${MD_FILE}"
