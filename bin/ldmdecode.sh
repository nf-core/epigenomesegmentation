#!/usr/bin/env bash

YAML=""
JSON=""
OUTPUT=""
THREADS=""

# Function to display help menu
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -y, --yaml <file>      Specify the input YAML file"
    echo "  -j, --json <file>      Specify the input JSON file"
    echo "  -o, --output <file>    Specify the output suffix"
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

get_counts_for_all.py -d "${YAML}" -o "counts_${OUTPUT}"


mkdir states_${OUTPUT}
for file in $(find "counts_${OUTPUT}" -name "counts*" -type f -print); do
    name=${file##*/counts_}

    TopologyHMM \
        -m "${JSON}" \
        -v "states_${OUTPUT}/viterbi_${name}" \
        -c "${file}" \
        -x "counts_${OUTPUT}/coverage_data_${name}" \
        -r "counts_${OUTPUT}/regions_${name}" \
        -p "${THREADS}"
done

segmentation_to_bed.py \
    -d "${YAML}" \
    -i "states_${OUTPUT}/" \
    -o "Segmentation/" \
    -c viterbi
