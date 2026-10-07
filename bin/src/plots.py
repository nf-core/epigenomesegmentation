#!/usr/bin/env python3
import numpy as np
import pandas as pd
import seaborn as sb
from scipy.stats import nbinom

import matplotlib
matplotlib.use('Agg')
from matplotlib.colors import LogNorm
import matplotlib.pyplot as plt

blue = (0.24715576253545807, 0.49918708160096675, 0.5765599057376697)
red = (0.7634747047461135, 0.3348456555528834, 0.225892295531744)


def set_plot_style():
    sb.set(font_scale=1.5)
    sb.set_style('whitegrid')
    # font = 'sans-serif'
    # font = 'serif'
    # sb.set(font_scale=1.5, rc={'text.usetex' : True})
    # sb.set_style('whitegrid')
    # if font == 'sans-serif':
    #     plt.rc('text.latex', preamble=r'\usepackage[cm]{sfmath}')
    # tex_fonts = {
    #     # Use LaTeX to write all text
    #     'text.usetex': True,
    #     'font.family': font,
    #     'axes.labelsize': 24,
    #     'font.size': 24,
    #     'legend.fontsize': 18,
    #     'xtick.labelsize': 20,
    #     'ytick.labelsize': 20,
    #     'text.color':'black'
    #     }
    # plt.rcParams.update(tex_fonts)


def plot_histogram(ax, MAX, data, step):
    data = np.clip(data, 0, MAX+1)
    _ = sb.histplot(ax=ax, data=data, discrete=True, color=blue, stat="probability")

    ticks = np.arange(0, MAX+1, step=step)
    ticklabels = [str(x) for x in ticks]
    ticklabels[-1] = str(MAX)+'+'
    ax.set_xticks(ticks, minor=False)
    ax.set_xticklabels(ticklabels, fontdict=None, minor=False)


def plot_state_distribution(data, column, MAX, HMM, filename, pmf):
    m = len(HMM['marker']) + len(HMM['coverage_marker'])
    _, axes = plt.subplots(HMM['states'], m, figsize=(8 * m, 5 * HMM['states']), squeeze=False)

    for i in range(HMM['states']):
        subset = data[data[column] == i + 1]
        for j in range(len(HMM['marker'])):
            if (i, j) != (0, 0):
                axes[i, j].sharex(axes[0, 0])
            plot_histogram(axes[i][j], MAX, subset.iloc[:, j], 50)
            axes[i, j].plot(np.arange(0, MAX), pmf(MAX, HMM, i, j), label='pmf', color=red)
            if j != 0:
                axes[i, j].set_ylabel("")
            if i != HMM['states'] - 1:
                axes[i, j].set_xlabel("")
        for k in range(len(HMM['coverage_marker'])):
            j = len(HMM['marker']) + k
            axes[i, j].set_xlim(-0.01, 1)
            sb.histplot(ax=axes[i, j], data=subset.iloc[:, j], color=blue, bins=201, stat='probability')
            if (HMM['emission'][i][j]['distribution'] == 'BI'):
                p = round(float(HMM['emission'][i][j]['parameters']['p']), 4)
                axes[i, j].vlines(x=p, ymin=0, ymax=axes[i, j].get_ylim()[1], colors=red)
            elif (HMM['emission'][i][j]['distribution'] == 'AB'):
                axes[i, j].plot(np.linspace(-0.005, 1, 200), pmf(MAX, HMM, i, j), label='pmf', color=red)
            else:
                axes[i, j].plot(np.linspace(0, 1, 199), pmf(MAX, HMM, i, j), label='pmf', color=red)
            axes[i, j].xaxis.set_ticks(np.append([-0.005], np.linspace(0, 1, 5)[1:]))
            axes[i, j].set_xticklabels(['nan'] + list(np.linspace(0, 1, 5))[1:])
            axes[i, j].set_xlabel("")
    plt.savefig(filename, bbox_inches='tight')


def plot_state_length_distribution(data, column, HMM, filename):
    label_groups = data[column].ne(data[column].shift()).cumsum()
    binsize = data.iloc[0, 2] - data.iloc[0, 1]
    combined = (data.groupby(label_groups).agg({'start': 'min', 'end': 'max', column: 'first'}).reset_index(drop=True))
    combined['length'] = combined['end'] - combined['start']
    combined['length'] /= binsize

    states = HMM['states']
    _, axes = plt.subplots(HMM['states'], figsize=(7, 5 * HMM['states']), squeeze=False)
    for s in range(1, states + 1):
        subset = combined.loc[combined[column] == s]
        histogram = np.zeros(int(subset['length'].max()) + 1, dtype=np.float64)
        for length in subset['length'].values:
            histogram[int(length)] += 1
        histogram /= histogram.sum()
        axes[s - 1, 0].plot(np.arange(1, subset['length'].max() + 1), histogram[1:], label='observed', color=blue)
        axes[s - 1, 0].fill_between(np.arange(1, subset['length'].max() + 1), histogram[1:], label='observed', color=blue, alpha=0.5)
        r = len(HMM['topology'][str(s)])
        start_state = int(HMM['topology'][str(s)][0])
        p = HMM['transition_matrix'][start_state][start_state]
        pmf = nbinom.pmf(range(0, int(subset['length'].max())), r, 1 - p)
        axes[s - 1, 0].plot(np.arange(r, subset['length'].max() + r), pmf, label='pmf', color=red)
        axes[s - 1, 0].fill_between(np.arange(r, subset['length'].max() + r), pmf, color=red, alpha=0.5)
        axes[s - 1, 0].set_xlabel('# Bins')
        axes[s - 1, 0].set_ylabel('Probability')
    plt.savefig(filename, bbox_inches='tight')


def plot_mean_emission(data, column, marks, cov_marks, states, filename, palette):
    # Set up grid based on whether we have coverage markers to plot
    total_marks = marks + cov_marks
    if cov_marks > 0:
        if marks > 0:
            fig, (ax_state, ax1, ax2) = plt.subplots(1, 3, figsize=(15, 10), gridspec_kw={'width_ratios': [0.5, marks, cov_marks], 'wspace': 0.1})
        else:
            fig, (ax_state, ax2) = plt.subplots(1, 2, figsize=(15, 10), gridspec_kw={'width_ratios': [0.5, cov_marks], 'wspace': 0.1})
            ax1 = None
    else:
        fig, (ax_state, ax1) = plt.subplots(1, 2, figsize=(15, 10), gridspec_kw={'width_ratios': [0.5, marks], 'wspace': 0.1})
        ax2 = None

    mean_emission = pd.DataFrame(columns=data.columns[:total_marks], dtype=float)

    for i in range(states):
        subset = data[data[column] == i + 1]
        subset = subset.iloc[:, :total_marks]
        mean_emission.loc[i] = subset.mean(axis=0, skipna=True).to_list()

    # Draw the colored state strip
    color_col = palette[:states].reshape((states, 1, 3))
    ax_state.imshow(color_col, aspect='auto')

    for i in range(states):
        ax_state.text(0, i, str(i+1), ha='center', va='center', color='black')

    ax_state.set_xticks([])
    ax_state.set_yticks([])

    # Plot normal markers (annot=False)
    if marks > 0 and ax1 is not None:
        sb.heatmap(ax=ax1, data=mean_emission.iloc[:, :marks], cmap=sb.light_palette(blue, input="rgb", as_cmap=True), cbar_kws={'label': 'Mean count'}, yticklabels=False, annot=False)
        ax1.set_xticklabels(labels=ax1.get_xticklabels(), rotation=90)

    # Plot coverage markers (annot=False)
    if cov_marks > 0 and ax2 is not None:
        sb.heatmap(ax=ax2, data=mean_emission.iloc[:, marks:total_marks], cmap=sb.light_palette(red, input="rgb", as_cmap=True), cbar_kws={'label': 'Mean proportion'}, yticklabels=False, annot=False)
        ax2.set_xticklabels(labels=ax2.get_xticklabels(), rotation=90)

    plt.savefig(filename, bbox_inches='tight')


def plot_mean_emission_norm(data, column, marks, cov_marks, states, filename, palette):
    fig, (ax_state, ax1) = plt.subplots(1, 2, figsize=(15, 10), gridspec_kw={'width_ratios': [0.5, max(1, marks+cov_marks)], 'wspace': 0.1})

    total_marks = marks + cov_marks
    norm_emission = pd.DataFrame(columns=data.columns[:total_marks], dtype=float)
    for i in range(states):
        subset = data[data[column] == i + 1]
        subset = subset.iloc[:, :total_marks]
        norm_emission.loc[i] = subset.mean(axis=0, skipna=True).to_list()

    min_val = norm_emission.min(axis=0)
    max_val = norm_emission.max(axis=0)
    norm_emission = (norm_emission - min_val) / (max_val - min_val)

    # Draw the colored state strip
    color_col = palette[:states].reshape((states, 1, 3))
    ax_state.imshow(color_col, aspect='auto')

    for i in range(states):
        ax_state.text(0, i, str(i+1), ha='center', va='center', color='black')

    ax_state.set_xticks([])
    ax_state.set_yticks([])

    # Plot the normalized emission heatmap (annot=False)
    sb.heatmap(ax=ax1, data=norm_emission.iloc[:, :total_marks], cmap=sb.light_palette(blue, input="rgb", as_cmap=True), cbar_kws={'label': 'Mean counts min-max normalized'}, yticklabels=False, annot=False)
    ax1.set_xticklabels(labels=ax1.get_xticklabels(), rotation=90)

    plt.savefig(filename, bbox_inches='tight')


def plot_transition(matrix, filename, palette):
    N = matrix.shape[0]
    fig, axes = plt.subplots(2, 3, figsize=(14, 12), gridspec_kw={'width_ratios': [1.5, 20, 1], 'height_ratios': [1.5, 20], 'wspace': 0.05, 'hspace': 0.05})

    ax_empty    = axes[0, 0]
    ax_top      = axes[0, 1]
    ax_empty_r  = axes[0, 2]
    ax_left     = axes[1, 0]
    ax_main     = axes[1, 1]
    ax_cbar     = axes[1, 2]
    ax_empty.axis('off')
    ax_empty_r.axis('off')

    col_strip_horz = palette[:N].reshape((1, N, 3))
    ax_top.imshow(col_strip_horz, aspect='auto')

    for i in range(N):
        ax_top.text(i, 0, str(i+1), ha='center', va='center', color='black')
    ax_top.set_axis_off()

    col_strip_vert = palette[:N].reshape((N, 1, 3))
    ax_left.imshow(col_strip_vert, aspect='auto')

    for i in range(N):
        ax_left.text(0, i, str(i+1), ha='center', va='center', color='black')
    ax_left.set_axis_off()

    sb.heatmap(matrix, ax=ax_main, cbar_ax=ax_cbar, cmap=sb.light_palette(blue, input="rgb", as_cmap=True), cbar_kws={'label': 'Transition probability'}, xticklabels=False, yticklabels=False)
    ax_cbar.yaxis.set_ticks([], minor=True)
    plt.savefig(filename, bbox_inches='tight')


def plot_correlation(data, filename):
    _, _ = plt.subplots(figsize=(16, 16))
    corr = data.corr()
    if data.shape[1] > 1:
        ax = sb.clustermap(corr, metric='correlation', cmap=sb.diverging_palette(20, 220, n=256), center=0, cbar_kws={'label': 'Correlation'}, yticklabels=1, xticklabels=1)
    else:
        ax = sb.heatmap(corr, vmin=-1, vmax=1, center=0, cmap=sb.diverging_palette(20, 220, n=256), square=True, annot=False)
    # ax.set_xticklabels(ax.get_xticklabels(), rotation=45, horizontalalignment='right')
    # ax.set_yticklabels(labels=ax.get_yticklabels(), va='center', rotation=0)
    plt.savefig(filename, bbox_inches = 'tight')


def plot_state_memberships(data, column, HMM, filename, palette):
    _, _ = plt.subplots(1, 1, figsize=(12, 10))
    membership = np.zeros(HMM['states'])
    total = data.shape[0]
    for i in range(HMM['states']):
        subset = data[data[column]==i+1]
        membership[i] = subset.shape[0] / total

    sb.barplot(y=np.arange(1, HMM['states']+1), x=membership, palette=palette.tolist(), orient='h')
    plt.ylabel("State")
    plt.xlabel("State membership")
    plt.savefig(filename, bbox_inches='tight')


def plot_state_length(data, column, filename, palette):
    label_groups = data[column].ne(data[column].shift()).cumsum()
    combined = (data.groupby(label_groups).agg({'start':'min', 'end':'max', column:'first'}).reset_index(drop=True))
    combined['length'] = combined['end'] - combined['start']

    _, ax = plt.subplots(1, 1, figsize=(12, 10))
    ax.set_xscale('log')
    sb.boxplot(y=combined[column], x=combined["length"], ax=ax, palette=palette.tolist(), orient='h')
    plt.ylabel("State")
    plt.xlabel("State length (bp)")
    plt.savefig(filename, bbox_inches='tight')


def plot_average_methylation(data, column, filename):
    _, ax = plt.subplots(1, 1, figsize=(12, 10))
    data = data[~np.isnan(data["DNA-Methylation"])]
    sb.boxplot(y=data[column], x=data["DNA-Methylation"], ax=ax, color=blue, orient='h')
    plt.ylabel("State")
    plt.xlabel("Average methylation")
    plt.savefig(filename, bbox_inches = 'tight')


def plot_methylation(ax, data):
    sb.histplot(ax=ax, data=data['prop'], color=blue, bins=200)

    ticks = np.arange(0, 1.1, step=0.2)
    ticklabels = ['nan'] + ['%.1f' % x for x in ticks]
    ax.set_xticks(np.append([-0.1], ticks), minor=False)
    ax.set_xticklabels(ticklabels, fontdict=None, minor=False)
    ax.set_ylabel("Counts")
    ax.set_xlabel("Proportion of methylated C")