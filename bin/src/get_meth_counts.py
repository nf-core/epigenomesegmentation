#!/usr/bin/env python3
import pandas as pd
import yaml
import argparse
import warnings


def all_counts(data, counts, regions):
    series = data['chr'].ne(data['chr'].shift())
    index = series[series].index

    with open(regions, 'w') as file:
        for r in index:
            file.write(str(r))
            file.write('\n')

    data = data.iloc[:, 3:]
    data.to_csv(counts, sep='\t', header=False, index=False)


def train_counts(config, data, counts, regions):
    chr = ['pilot_hg38']
    if 'chr' in config:
        chr = config['chr']
        if type(chr) is list:
            chr = [str(x) for x in chr]
        else:
            chr = [str(chr)]

    train = []
    if chr[0].startswith('pilot'):
        if chr[0] == 'pilot_hg19':
            pilot = pd.read_csv("src/encode_pilot_regions/hg19.bed", sep="\t", names=['chr', 'start', 'end', 'name'])
        else:
            pilot = pd.read_csv("src/encode_pilot_regions/hg38.bed", sep="\t", names=['chr', 'start', 'end', 'name'])

        for row in pilot['chr'].index:
            chr_data = data[data["chr"] == pilot.loc[row]['chr']]
            chr_data = chr_data.loc[(chr_data['start'] >= pilot.loc[row]['start']) & (chr_data['end'] < pilot.loc[row]['end'])]
            chr_data = chr_data.iloc[:, 3:]
            train.append(chr_data)

    else:
        for c in chr:
            chr_data = data[data["chr"] == c]
            chr_data = chr_data.iloc[:, 3:]
            train.append(chr_data)

    train = pd.concat(train, axis=0)
    train.to_csv(counts, sep='\t', header=False, index=False)

    with open(regions, 'w') as file:
        file.write('0')


warnings.simplefilter(action='ignore', category=FutureWarning)
parser = argparse.ArgumentParser(description="Create count matrices.")
parser.add_argument("-d", metavar="config", type=str, nargs=1, help="Yaml file with path to data file.")
parser.add_argument("-c", metavar="trainCounts", type=str, nargs=1, help="Output file with train counts.")
parser.add_argument("-r", metavar="trainRegions", type=str, nargs=1, help="Output file train regions.")
parser.add_argument("-C", metavar="counts", type=str, nargs=1, help="Output file with counts.")
parser.add_argument("-R", metavar="regions", type=str, nargs=1, help="Output file with regions.")
args = parser.parse_args()

try:
    configFile = args.d[0]
    trainCounts = args.c[0]
    trainRegions = args.r[0]
    counts = args.C[0]
    regions = args.R[0]
except:
    parser.print_help()
    exit()

config = dict()
with open(configFile) as file:
    config = yaml.safe_load(file)
file = config['coverage_data'][0]

data = pd.read_csv(file, sep='\t', converters={0: str, 1: int})
data['chr'] = data['chr'].map(lambda x: x[3:] if x.startswith('chr') else x)
# data.columns = ['chr', 'start', 'end', 'Cov', 'Meth']
# data.sort_values(by=['chr', 'start'], inplace=True)
# data.reset_index(inplace=True, drop=True)

all_counts(data, counts, regions)
train_counts(config, data, trainCounts, trainRegions)
