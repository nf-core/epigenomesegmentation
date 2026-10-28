#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# ==============================================================================
# Initialize Variables
# ==============================================================================
TRAINCOUNTS=""
TRAINMETHCOUNTS=""
TRAINREGIONS=""
YAML=""
OUTPUT=""
ITERATIONS=""
EPSILON=""
THREADS=""

# ==============================================================================
# Functions
# ==============================================================================
usage() {
    cat <<HELP
Usage: \$(basename "\$0") [OPTIONS]

Options for creating topology JSON files:
  -c, --traincounts       Training counts file path
  -m, --trainmethcounts   Training methylation counts file path
  -r, --trainregions Training regions file path
  -y, --yaml         YAML configuration file
  -o, --output       Base name for output files

Options for DM model training:
  -i, --iterations   Number of iterations
  -e, --epsilon      Epsilon value
  -@, --threads      Number of threads

Other:
  -h, --help         Display this help message and exit
HELP
    exit 1
}

# ==============================================================================
# Parse Command-Line Arguments
# ==============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--traincounts)       TRAINCOUNTS="$2"; shift 2 ;;
        -m|--trainmethcounts)   TRAINMETHCOUNTS="$2"; shift 2 ;;
        -r|--trainregions) TRAINREGIONS="$2"; shift 2 ;; # <-- ADDED THIS LINE
        -y|--yaml)         YAML="$2"; shift 2 ;;
        -o|--output)       OUTPUT="$2"; shift 2 ;;
        -i|--iterations)   ITERATIONS="$2"; shift 2 ;;
        -e|--epsilon)      EPSILON="$2"; shift 2 ;;
        -@|--threads)      THREADS="$2"; shift 2 ;;
        -h|--help)         usage ;;
        *)
            echo "Error: Unknown parameter '$1'" >&2
            usage
            ;;
    esac
done

# ==============================================================================
# Validation
# ==============================================================================
# Ensure no arguments are left empty (ADDED $TRAINREGIONS HERE)
if [[ -z "$TRAINCOUNTS" || -z "$TRAINMETHCOUNTS" || -z "$TRAINREGIONS" || \
      -z "$YAML" || -z "$OUTPUT" ||  \
      -z "$ITERATIONS" || -z "$EPSILON" || -z "$THREADS" ]]; then
    echo "Error: Missing required arguments." >&2
    usage
fi

# ==============================================================================
# Execution
# ==============================================================================
echo "1/2: Initializing HMM..."
init_HMM.py \
    -d "$TRAINCOUNTS" \
    -e "$TRAINMETHCOUNTS" \
    -m "$YAML" \
    -j "${OUTPUT}-init.json"



echo "2/2: Running TopologyHMM..."
HMMChromSeg \
    -t \
    -m "${OUTPUT}-init.json" \
    -o "final-model-${OUTPUT}.json" \
    -c "${TRAINCOUNTS}" \
    -x "${TRAINMETHCOUNTS}" \
    -r "${TRAINREGIONS}"    \
    -i "${ITERATIONS}" \
    -e "${EPSILON}" \
    -p "${THREADS}" &> "${OUTPUT}.log"

echo "DMTRAIN completed successfully. Log saved to ${OUTPUT}.log"
