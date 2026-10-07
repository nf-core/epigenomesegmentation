#!/usr/bin/env bash

# Exit immediately if a command fails, an undefined variable is used, or a pipeline fails
set -euo pipefail

# ==========================================
# Variable Initialization
# ==========================================
NAME=""
OUTPUT_DIR=""
PLOT_STATISTICS="false"

# ==========================================
# Functions
# ==========================================
show_help(){
    cat <<'HELP'
Usage: $(basename "$0") [OPTIONS]

Options for generating the HTML report:
    -n, --name              Base name for the sample
    -o, --output-dir        Output directory for the HTML file
    -i, --plot-statistics   Include statistics plots (true/false)
    -h, --help              Show this help message and exit
HELP
}

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
        -i|--plot-statistics)
            PLOT_STATISTICS="$2"
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
if [[ -z "${NAME}" || -z "${OUTPUT_DIR}" ]]; then
    echo "Error: Missing required arguments (--name and --output-dir are required)." >&2
    show_help
    exit 1
fi

# ==========================================
# Main Execution
# ==========================================
# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

OUTPUT_FILE="${OUTPUT_DIR}/${NAME}.html"

# Convert PLOT_STATISTICS to lowercase for robust string comparison
PLOT_STATISTICS=$(echo "${PLOT_STATISTICS}" | tr '[:upper:]' '[:lower:]')

if [[ "${PLOT_STATISTICS}" == "false" ]]; then

cat << EOF > "${OUTPUT_FILE}"
<!DOCTYPE html>
<html>
<head>
<title>${NAME} - EpiSegMix Report</title>
<style>
  img {
    max-width: 70%;
    height: auto;
    display: block;
    margin: 0 auto;
  }
  .text-above-figure {
    text-align: center;
    font-weight: bold;
  }
</style>
</head>
<body>
<h1><center>EpiSegMix Report: ${NAME}</center></h1><br>
<center>
<div class="text-above-figure"><h2>Segmentation</h2><br><a>State colors<br><img src="${NAME}-state-colors.png"></a></div>
<br>
<div class="text-above-figure"><h2>Normalized counts</h2><br><img src="${NAME}-normEmission.png"></div>
<br>
<div class="text-above-figure"><h2>Characteristics</h2><br>
<table>
<tr>
  <td valign="top"><a>Transition matrix<br><img src="${NAME}-transitionMatrix.png"></a></td>
  <td valign="top"><a>Average length<br><img src="${NAME}-stateLength.png"></a></td>
  <td valign="top"><a>Coverage<br><img src="${NAME}-stateMembership.png"></a></td>
</tr>
</table>
</div>
</center>
</body>
</html>
EOF

else 

cat << EOF > "${OUTPUT_FILE}"
<!DOCTYPE html>
<html>
<head>
<title>${NAME} - EpiSegMix Report</title>
<style>
  img {
    max-width: 70%;
    height: auto;
    display: block;
    margin: 0 auto;
  }
  .text-above-figure {
    text-align: center;
    font-weight: bold;
  }
</style>
</head>
<body>
<h1><center>EpiSegMix Report: ${NAME}</center></h1><br>
<center>
<div class="text-above-figure"><h2>Segmentation</h2><br><a>State colors<br><img src="${NAME}-state-colors.png"></a></div>
<br>
<div class="text-above-figure"><h2>Normalized counts</h2><br><img src="${NAME}-normEmission.png"></div>
<br>
<div class="text-above-figure"><h2>Characteristics</h2><br>
<table>
<tr>
  <td valign="top"><a>Transition matrix<br><img src="${NAME}-transitionMatrix.png"></a></td>
  <td valign="top"><a>Average length<br><img src="${NAME}-stateLength.png"></a></td>
  <td valign="top"><a>Coverage<br><img src="${NAME}-stateMembership.png"></a></td>
</tr>
</table>
</div>
<br>
<div class="text-above-figure"><h2>Emission distribution</h2><br><img src="${NAME}-stateDistribution.png"></div>
<br>
<div class="text-above-figure"><h2>Input characteristics</h2><br>
<table>
<tr>
  <td valign="top">Correlation<br><img src="${NAME}-correlation.png"></td>
  <td valign="top">Distributions<br><img src="${NAME}-histogram.png"></td>
</tr>
</table>
</div>
</center>
</body>
</html>
EOF

fi 

echo "HTML report generated at ${OUTPUT_FILE}"