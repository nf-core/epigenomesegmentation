#!/usr/bin/env python3
"""
Init HMM states based on method of moment estimators
"""
import argparse
import warnings
import json
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
import yaml

from distribution import param, meth_param


def init_k_means(data, k, marker, nmarker, distributions, file, coverage=None, cov_marker=0):
    json_data = {}

    json_data["states"] = k
    json_data["marker"] = marker[:nmarker]
    json_data["coverage_marker"] = marker[nmarker:]
    assert len(json_data["coverage_marker"]) == cov_marker
    json_data["emission"] = []

    scaler = StandardScaler()
    scaled_features = scaler.fit_transform(data)
    try:
        kmeans = KMeans(init="random", n_clusters=k, n_init=10, max_iter=300, random_state=42)
        kmeans.fit(scaled_features)

        mean = np.empty((k, data.shape[1]))
        std = np.empty((k, data.shape[1]))
        zero = np.empty((k, data.shape[1]))
        n = np.empty((k, data.shape[1]))
        for i in range(k):
            subset = data[kmeans.labels_ == i]
            values = subset.values
            for j in range(nmarker):
                mean[i, j] = values[:, j].mean()
                std[i, j] = values[:, j].std()
                zero[i, j] = np.count_nonzero(values[:, j] == 0) / len(values[:, j])
                n[i, j] = max(values[:, j])

        if json_data["coverage_marker"]:
            mean_cov = np.empty((k, data.shape[1]))
            std_cov = np.empty((k, data.shape[1]))
            zero_cov = np.empty((k, data.shape[1]))
            for i in range(k):
                subset = coverage[kmeans.labels_ == i]
                values = subset.values
                for j in range(cov_marker):
                    mean_cov[i, j] = np.nanmean(values[:, j])
                    std_cov[i, j] = np.nanstd(values[:, j])
                    zero_cov[i, j] = np.count_nonzero(values[:, j] == 0) / len(values[:, j])

        maxN = np.empty(data.shape[1])
        for i in range(data.shape[1]):
            maxN[i] = max(data.values[:, i])

        for i in range(k):
            state = []
            for j in range(nmarker):
                state.append({"distribution": distributions[j], "parameters": param(distributions[j], mean[i, j], std[i, j], zero[i, j], n[i, j], maxN[j])})
            for j in range(cov_marker):
                idx = nmarker + j
                state.append({"distribution": distributions[idx], "parameters": meth_param(distributions[idx], mean_cov[i, j], std_cov[i, j], zero_cov[i, j])})
            json_data["emission"].append(state)
    except:
        json_data["emission"] = []
        for i in range(k):
            state = []
            for _ in range(nmarker):
                state.append({"distribution": 'PO', "parameters": {"lambda": 1}})
            for _ in range(cov_marker):
                state.append({"distribution": 'BI', "parameters": {"p": 0.5}})
            json_data["emission"].append(state)

    with open(file, 'w') as jsonFile:
        json.dump(json_data, jsonFile, indent=4)


def init_k_means_meth(data, k, markers, distributions, file):
    json_data = {}
    json_data["states"] = k
    json_data["marker"] = []
    json_data["emission"] = []
    json_data["coverage_marker"] = markers
    m = len(markers)

    scaler = StandardScaler()
    scaled_features = scaler.fit_transform(data)
    try:
        kmeans = KMeans(init="random", n_clusters=k, n_init=10, max_iter=300, random_state=42)
        kmeans.fit(scaled_features)

        mean_cov = np.empty((k, data.shape[1]))
        std_cov = np.empty((k, data.shape[1]))
        zero_cov = np.empty((k, data.shape[1]))
        for i in range(k):
            subset = data[kmeans.labels_ == i]
            values = subset.values
            for j in range(m):
                mean_cov[i, j] = np.nanmean(values[:, j])
                std_cov[i, j] = np.nanstd(values[:, j])
                zero_cov[i, j] = np.count_nonzero(values[:, j] == 0) / len(values[:, j])

        for i in range(k):
            state = []
            for j in range(m):
                state.append({"distribution": distributions[j], "parameters": meth_param(distributions[j], mean_cov[i, j], std_cov[i, j], zero_cov[i, j])})
            json_data["emission"].append(state)
    except:
        json_data["emission"] = []
        for i in range(k):
            state = []
            state.append({"distribution": 'BI', "parameters": {"p": 0.5}})
            json_data["emission"].append(state)

    with open(file, 'w') as jsonFile:
        json.dump(json_data, jsonFile, indent=4)


def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)

    parser = argparse.ArgumentParser(description="Initialize HMM.")
    parser.add_argument("-d", metavar="data", type=str, nargs=1, default=[''], help="Input data.")
    parser.add_argument("-e", metavar="coverage-data", type=str, nargs=1, default='', help="Optional coverage data, e.g., DNA methylation.")
    parser.add_argument("-m", metavar="marker", type=str, nargs=1, help="YAML file with marker information (name and distributional assumption).")
    parser.add_argument("-j", metavar="json", type=str, nargs=1, help="Output json file with initial HMM parameters.")
    args = parser.parse_args()

    try:
        marker_file = args.m[0]
        data_file = args.d[0]
        out = args.j[0]
    except:
        parser.print_help()
        return

    marker = dict()
    with open(marker_file) as file:
        marker = yaml.safe_load(file)

    if data_file != '':
        k = marker['states']
        m = marker['marker']
        data = pd.read_csv(data_file, sep='\t', header=None)
        names = []
        distribution = []
        for i in range(m):
            distribution.append(marker['marker_spec'][i]['distribution'])
            names.append(marker['marker_spec'][i]['name'])

        if 'coverage_data' in marker:
            nmarker = marker['coverage_marker']
            coverage_data = pd.read_csv(args.e[0], sep='\t', names=[f(i) for i in range(nmarker) for f in (lambda x: f'C{x}', lambda x: f'M{x}')])
            for i in range(nmarker):
                coverage_data[f'prop_{i}'] = coverage_data[f'M{i}'] / coverage_data[f'C{i}']
                distribution.append(marker['coverage_marker_spec'][i]['distribution'])
                names.append(marker['coverage_marker_spec'][i]['name'])
            coverage_data = coverage_data.drop([f(i) for i in range(nmarker) for f in (lambda x: f'C{x}', lambda x: f'M{x}')], axis=1)
            init_k_means(data, k, names, m, distribution, out, coverage_data, nmarker)
        else:
            init_k_means(data, k, names, m, distribution, out)
    else:
        k = marker['states']
        nmarker = marker['coverage_marker']
        coverage_data = pd.read_csv(args.e[0], sep='\t', names=[f(i) for i in range(nmarker) for f in (lambda x: f'C{x}', lambda x: f'M{x}')])
        distribution = []
        names = []
        for i in range(nmarker):
            coverage_data[f'prop_{i}'] = coverage_data[f'M{i}'] / coverage_data[f'C{i}']
            distribution.append(marker['coverage_marker_spec'][i]['distribution'])
            names.append(marker['coverage_marker_spec'][i]['name'])
        coverage_data = coverage_data.drop([f(i) for i in range(nmarker) for f in (lambda x: f'C{x}', lambda x: f'M{x}')], axis=1)
        coverage_data = coverage_data.fillna(0.0)
        init_k_means_meth(coverage_data, k, names, distribution, out)


if __name__ == "__main__":
    main()
