#!/usr/bin/env python3
"""
Create count matrices for HMM training
"""
import argparse
import warnings
import yaml
import pandas as pd


def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)
    parser = argparse.ArgumentParser(description="Create count matrices.")
    parser.add_argument("-d", metavar="model", type=str, nargs=1, help="Yaml file with path to data files.")
    parser.add_argument("-c", metavar="train", type=str, nargs=1, help="Output file.")
    parser.add_argument("-m", metavar="trainCov", type=str, nargs=1, help="Output file for coverage data (e.g. DNA methylation).")
    parser.add_argument("-r", metavar="regions", type=str, nargs=1, help="Output for index to indicate start of separate regions.")
    args = parser.parse_args()

    try:
        data = args.d[0]
        train_file = args.c[0]
        train_cov_file = args.m[0]
        region_file = args.r[0]
    except:
        parser.print_help()
        return

    marker = {}
    with open(data) as file:
        marker = yaml.safe_load(file)
    files = marker['data']

    chr = ['pilot_hg38']
    if 'chr' in marker:
        chr = marker['chr']
        if type(chr) is list:
            chr = [str(x) for x in chr]
        else:
            chr = [str(chr)]

    cov_files = []
    if 'coverage_marker' in marker:
        cov_files = marker['coverage_data']
        if len(files) != len(cov_files):
            raise ValueError('Number of histone counts and coverage counts (e.g., WGBS DNA methylation) must correspond!')

    columns = [str(mark['name']) for mark in marker['marker_spec']]

    train = []
    train_cov = []
    index = []
    start = 0
    for i in range(len(files)):
        data = pd.read_csv(files[i], sep='\t', converters={0: str})
        data.columns = ['chr', 'start', 'end'] + list(data.columns)[3:]
        data['chr'] = data['chr'].map(lambda x: x[3:] if x.startswith('chr') else x)

        if chr[0].startswith('pilot'):
            if chr[0] == 'pilot_hg19':
                pilot = pd.read_csv("src/encode_pilot_regions/hg19.bed", sep="\t", names=['chr', 'start', 'end', 'name'])
            else:
                pilot = pd.read_csv("src/encode_pilot_regions/hg38.bed", sep="\t", names=['chr', 'start', 'end', 'name'])

            rows = 0
            for row in pilot['chr'].index:
                chr_data = data[data["chr"] == pilot.loc[row]['chr']]
                chr_data = chr_data.loc[(chr_data['start'] >= pilot.loc[row]['start']) & (chr_data['end'] < pilot.loc[row]['end'])]
                chr_data = chr_data.iloc[:, 3:]
                chr_data = pd.DataFrame(chr_data, columns=columns)
                train.append(chr_data)

                if 'coverage_marker' in marker:
                    cov_data = pd.read_csv(cov_files[i], sep='\t')
                    cov_data = cov_data.iloc[chr_data.index[0]:chr_data.index[-1] + 1, :]
                    train_cov.append(cov_data)

                rows += chr_data.shape[0]

            index.append(start)
            start += rows
        elif chr[0] == 'all':
            hist_data = data.iloc[:, 3:]
            hist_data = pd.DataFrame(data, columns=columns)
            train.append(hist_data)
            if 'coverage_marker' in marker:
                cov_data = pd.read_csv(cov_files[i], sep='\t')
                train_cov.append(cov_data)
            series = data['chr'].ne(data['chr'].shift())
            index.extend([start + x for x in series[series].index])
            start += hist_data.shape[0]
        else:
            for c in chr:
                chr_data = data[data["chr"] == c]
                chr_data = chr_data.iloc[:, 3:]
                chr_data = pd.DataFrame(chr_data, columns=columns)
                train.append(chr_data)

                if 'coverage_marker' in marker:
                    cov_data = pd.read_csv(cov_files[i], sep='\t')
                    cov_data = cov_data.iloc[chr_data.index[0]:chr_data.index[-1] + 1, :]
                    train_cov.append(cov_data)

                index.append(start)
                start += chr_data.shape[0]

    train = pd.concat(train, axis=0)
    train.to_csv(train_file, sep='\t', header=False, index=False)

    with open(region_file, 'wt') as file:
        for r in index:
            file.write(str(r))
            file.write('\n')

    if 'coverage_marker' in marker:
        train_cov = pd.concat(train_cov, axis=0)
        train_cov.to_csv(train_cov_file, sep='\t', header=False, index=False)
    else:
        with open(train_cov_file, 'w') as _:
            pass


if __name__ == "__main__":
    main()
