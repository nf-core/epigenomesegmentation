#!/usr/bin/env bash

YAML=""
JSON=""
OUTPUT=""
THREADS=""
COUNTS=""
REGION=""
BINNED=""

# Function to display help menu
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -y, --yaml <file>      Specify the input YAML file"
    echo "  -j, --json <file>      Specify the input JSON file"
    echo "  -o, --output <file>    Specify the output suffix"
    echo "  -c,  --counts <file>   Specify the counts file"
    echo "  -r,  --region <file>   Specify the file containg the regions"
    echo "  -@, --threads <num>    Specify the number of threads to use"
    echo "  -h, --help             Display this help message and exit"
    echo ""
    exit 0
}

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
        -c|--counts)
            COUNTS="$2"
            shift 2
            ;;
        -r|--region)
            REGIONS="$2"
            shift 2
            ;;
        -b|binned)
            BINNED="$2"
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
            usage
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            echo "Run '$0 --help' for usage information." >&2
            exit 1
            ;;
    esac
done

touch states.txt

cut -f 4,5 ${COUNTS} > tmp_counts.txt
sed -i '1d' tmp_counts.txt
TopologyHMM \
    -m "${JSON}" \
    -v "states.txt" \
    -x "tmp_counts.txt" \
    -r "${REGION}" \
    -p "${THREADS}"
rm -rf tmp_counts.txt

segmentation_to_bed.py \
    -d "${YAML}" \
    -i "states.txt" \
    -o "Segmentation/" \
    -c viterbi
