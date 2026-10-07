#!/usr/bin/env python3
import argparse
import warnings
import pandas as pd
import seaborn as sb

import matplotlib
matplotlib.use('Agg')
import matplotlib.colors as mcolors


def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)
    
    parser = argparse.ArgumentParser(description = "Convert segmentation to bed format.")
    parser.add_argument("-d", metavar = "data", type = str, nargs = 1, help = "Data with chromosome position and segmentation information.")
    parser.add_argument("-o", metavar = "output", type = str, nargs = 1, help = "Output file.")
    parser.add_argument("-c", metavar = "column", type = str, nargs = 1, help = "Column with state sequence (either viterbi or posterior).")
    args = parser.parse_args()

    try:
        data = args.d[0]
        output = args.o[0]
        column = args.c[0]
    except:
        parser.print_help()
        return

    data = pd.read_csv(data, sep='\t', converters={'chr':str}, index_col=0)

    combined = []
    for chr in set(data.index):
        subset = data.loc[[chr]]
        label_groups = subset[column].ne(subset[column].shift()).cumsum()
        subset = (subset.groupby(label_groups).agg({'start':'min', 'end':'max', column:'first'}).reset_index(drop=True))
        subset.index = [chr] * subset.shape[0]
        combined.append(subset)

    combined = pd.concat(combined, ignore_index=False)

    combined['score'] = 0
    combined['strand'] = '.'
    combined['thickStart'] = combined['start']
    combined['thickEnd'] = combined['end']

    s = max(combined[column])
    #alternatively use "cubehelix" or "husl"
    cmap = sb.color_palette("hls", s)
    cmap = [mcolors.to_hex(c) for c in cmap]
    cmap = [tuple(int(hex[i+1:i+3], 16) for i in (0, 2, 4)) for hex in cmap]

    combined['rgb']=[','.join(map(str, cmap[x-1])) for x in combined[column]]
    combined.index = 'chr' + combined.index
    combined.to_csv(output, sep='\t', header=False)


if __name__ == "__main__":
    main()