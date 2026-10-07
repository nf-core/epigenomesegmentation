#!/usr/bin/env python3
import argparse
import pandas as pd
import warnings

def main():
    warnings.simplefilter(action='ignore', category=FutureWarning)
    
    parser = argparse.ArgumentParser(description = "Convert posterior scores to bedGraph format.")
    parser.add_argument("-d", metavar = "data", type = str, nargs = 1, help = "Data with chromosome positions and segmentation score.")
    parser.add_argument("-o", metavar = "output", type = str, nargs = 1, help = "Output file.")
    args = parser.parse_args()

    try:
        data = args.d[0]
        output = args.o[0]
    except:
        parser.print_help()
        return

    data = pd.read_csv(data, sep='\t', converters={0:str})
    data.columns = ['chr', 'start', 'end'] + list(data.columns)[3:]

    data['chr'] = 'chr' + data['chr']
    data.drop(columns = data.columns[3:data.shape[1]-1],inplace=True)
    data.to_csv(output, sep='\t', header=False, index=False)

if __name__ == "__main__":
    main()