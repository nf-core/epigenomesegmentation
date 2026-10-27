#!/usr/bin/env python3
import argparse
import math
import numpy as np
import pandas as pd
import json
import warnings

import plots
from distribution import pmf


def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)
    
    parser = argparse.ArgumentParser(description="Results of chromatin segmentation.")
    parser.add_argument("-c", metavar="data", type=str, nargs=1, help="Data with histone modifcations and segmentation.")
    parser.add_argument("-j", metavar="json", type=str, nargs=1, help="Json file with HMM parameters.")
    parser.add_argument("-a", metavar="state_distribution", type=str, nargs=1, help="Plot state distribution (histogram with pdf).")
    parser.add_argument("-l", metavar="statelength_distribution", type=str, nargs=1, help="Plot state length distribution (histogram with pdf).")
    parser.add_argument("-s", metavar="states", type=str, nargs=1, help="Column name with state sequence.")
    args = parser.parse_args()

    try:
        data = args.c[0]
        model = args.j[0]
        stateDistribution = args.a[0]
        statelengthDistribution = args.l[0]
        column = args.s[0]
    except:
        parser.print_help()
        return

    HMM = dict()
    with open(model) as file:
        HMM = json.load(file)
    HMM['states'] = int(HMM['states'])
    HMM['initial_state_distribution'] = np.array(HMM['initial_state_distribution'], dtype=float)
    HMM['transition_matrix'] = np.array(HMM['transition_matrix'], dtype=float)

    m = len(HMM['marker'])
    cm = len(HMM['coverage_marker'])
    data = pd.read_csv(data, sep='\t', converters={0: str})
    data.columns = ['chr', 'start', 'end'] + list(data.columns)[3:]
    max = int(math.ceil(np.percentile(data.iloc[:, 3:3 + m].values, 99.5) / 100.0)) * 100

    old_columns = list(data.columns)
    drop_columns = []
    for i in range(cm):
        columns = list(data.columns[3 + m + 2 * i: 3 + m + 2 * i + 2])
        drop_columns += columns
        data[HMM['coverage_marker'][i]] = data[columns[1]] / data[columns[0]]

    data = data.drop(columns=drop_columns)
    new_cols = HMM['coverage_marker'] if len(HMM['coverage_marker']) > 0 else []
    new_cols = old_columns[:m + 3] + new_cols + old_columns[3 + m + 2 * cm:]
    data = data[new_cols]
    data = data.fillna(-0.005)

    plots.set_plot_style()
    plots.plot_state_distribution(data.iloc[:, 3:], column, max, HMM, stateDistribution, pmf)
    plots.plot_state_length_distribution(data, column, HMM, statelengthDistribution)


if __name__ == "__main__":
    main()
