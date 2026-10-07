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
ADJUSTMENT=""
ITERATIONS=""
EPSILON=""
THREADS=""

# ==============================================================================
# Functions
# ==============================================================================
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options for creating topology JSON files:
  -c, --traincounts       Training counts file path
  -m, --trainmethcounts   Training methylation counts file path
  -r, --trainregions Training regions file path
  -y, --yaml         YAML configuration file
  -o, --output       Base name for output files

Options for DNA model training:
  -a, --adjustment   Adjustment parameter
  -i, --iterations   Number of iterations
  -e, --epsilon      Epsilon value
  -@, --threads      Number of threads

Other:
  -h, --help         Display this help message and exit
EOF
    exit 1
}

# ==============================================================================
# Parse Command-Line Arguments
# ==============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--traincounts)       TRAINCOUNTS="$2"; shift 2 ;;
        -m|--trainmethcounts)   TRAINMETHCOUNTS="$2"; shift 2 ;;
        -r|--trainregions) TRAINREGIONS="$2"; shift 2 ;;
        -y|--yaml)         YAML="$2"; shift 2 ;;
        -o|--output)       OUTPUT="$2"; shift 2 ;;
        -a|--adjustment)   ADJUSTMENT="$2"; shift 2 ;;
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
      -z "$YAML" || -z "$OUTPUT" || -z "$ADJUSTMENT" || \
      -z "$ITERATIONS" || -z "$EPSILON" || -z "$THREADS" ]]; then
    echo "Error: Missing required arguments." >&2
    usage
fi

# ==============================================================================
# Execution
# ==============================================================================

echo "1/3: Initializing HMM..."
init_HMM.py \
    -e "$TRAINCOUNTS" \
    -m "$YAML" \
    -j "${OUTPUT}-preinit.json"

echo "2/3: Adding topology to initial model..."
add_topology_to_init.py \
    --input "${OUTPUT}-preinit.json" \
    --output "${OUTPUT}-init.json"

echo "3/3: Running TopologyHMM..."
TopologyHMM \
    -t \
    -n "${ADJUSTMENT}" \
    -m "${OUTPUT}-init.json" \
    -o "final-model-${OUTPUT}.json" \
    -x "${TRAINCOUNTS}" \
    -r "${TRAINREGIONS}"    \
    -i "${ITERATIONS}" \
    -e "${EPSILON}" \
    -p "${THREADS}" &> "${OUTPUT}.log"

echo "DNARAIN completed successfully. Log saved to ${OUTPUT}.log"
