#!/usr/bin/env python3
import argparse
import warnings
import numpy as np
import pandas as pd

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def set_plot_style():
    font = 'serif'
    tex_fonts = {
        # Use LaTeX to write all text
        'text.usetex': True,
        'font.family': font,
        'axes.labelsize': 26,
        'font.size': 26,
        'legend.fontsize': 26,
        'xtick.labelsize': 26,
        'ytick.labelsize': 26,
        'text.color': 'black'
    }
    plt.rcParams.update(tex_fonts)


def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)

    parser = argparse.ArgumentParser(description="Plot state colors.")
    parser.add_argument("-d", metavar="data", type=str, nargs=1, help="Segmentation.")
    parser.add_argument("-o", metavar="output", type=str, nargs=1, help="Output filename.")
    args = parser.parse_args()

    # Read BED file, forcing both chromosome (0) and state name (3) to be read as strings
    data = pd.read_csv(args.d[0], sep='\t', header=None, skiprows=[0], converters={0: str, 3: str})

    # Extract unique states and sort them perfectly (1, 2, 3...) to fix the scrambling issue
    unique_states = list(data[3].unique())
    states = sorted(unique_states, key=lambda x: int(''.join(filter(str.isdigit, str(x)))) if any(c.isdigit() for c in str(x)) else x)

    # Your original palette generation (now receiving correctly sorted states)
    palette = np.zeros((len(states), 3), dtype=int)
    for i in range(len(states)):
        palette[i, :] = [int(x) for x in data[data[3] == states[i]].iloc[0, 8].split(',')]

    # set_plot_style()

    arr = np.array([[x for x in range(len(states))]], dtype=int)
    RGB = palette[arr]
    plt.imshow(RGB)
    plt.yticks([])
    plt.xticks(list(range(0, len(states))), [str(x) for x in range(1, len(states) + 1)])

    plt.savefig(args.o[0], bbox_inches='tight')


if __name__ == "__main__":
    main()