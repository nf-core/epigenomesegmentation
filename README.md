<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-epigenomesegmentation_logo_dark.png">
    <img alt="nf-core/epigenomesegmentation" src="docs/images/nf-core-epigenomesegmentation_logo_light.png">
  </picture>
</h1>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/nf-core/epigenomesegmentation)
[![GitHub Actions CI Status](https://github.com/nf-core/epigenomesegmentation/actions/workflows/nf-test.yml/badge.svg)](https://github.com/nf-core/epigenomesegmentation/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/epigenomesegmentation/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/epigenomesegmentation/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/epigenomesegmentation/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.5.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.5.2)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/epigenomesegmentation)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23epigenomesegmentation-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/epigenomesegmentation)[![Follow on Bluesky](https://img.shields.io/badge/bluesky-%40nf__core-1185fe?labelColor=000000&logo=bluesky)](https://bsky.app/profile/nf-co.re)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/epigenomesegmentation** is a bioinformatics pipeline for chromatin segmentation. It uses a hidden Markov model (HMM) to annotate genomic regions with functional states (e.g., enhancers, promoters) based on combinations of epigenetic modifications, capturing spatial relations via transition probabilities.

![nf-core/epigenomesegmentation metro map](docs/images/nf-core-epigenomesegmentation_dark.png)

<a href='https://www.denbi.de/about'> <img src="docs/images/denbi-logo.png" align="right" width="150"> </a>

This is an approved de.NBI service. Please help us improve by taking our short user survey (<https://de.surveymonkey.com/r/denbi-service?sc=hd-hub&tool=esmm>).

## Default Workflow: Topology Modelling
By default, the EPIGENOMESEGMENTATION pipeline executes the **Topology Modeling**.

### Execution Steps

1. **Genome Processing:** It includes 4 modules (`GET_CHROMSIZES`, `FILTER_CHROMSIZES`, `SORT_REFRENCE` & `MAKE_WINDOWS`) to generate a binned window size reference BED file based on parameter `--binsize and --genome` (200 and hg38 by default) along with a sorted reference chromosome sizes tab file.

2. **BAM Processing:** It includes 4 modules (`SAMTOOLS_REHEADER`, `SAMTOOLS_INDEX`, `BAM_SHEET` & `BAM_COUNTS`) to generate a count matrix for histone marks using BAM files as input for the tool [EpiSegMix](https://doi.org/10.1101/2025.07.25.666820).

3. **BED Processing:** It includes 2 modules (`BED_COUTNS` & `BEDTOOLS_MAP`) to generate a count matrix for coverage markers using BED files as input for the tool [EpiSegMix](https://doi.org/10.1101/2025.07.25.666820).

4. **Merging:** It includes 4 modules (`STRIPHEADER`, `BEDTOOLS_INTERSECT`, `FILTER_BED` & `JOINBED`) to standardize the files to have the same number of rows and same genomic positions between histone and coverage counts is also responsible for merging the different coverage counts files together in one file.

5. **EpiSegMix Prepare:** It includes 2 modules (`CONFIG` & `TRAINCOUNTS`) These generate a config file along with the training counts for the tool [EpiSegMix](https://doi.org/10.1101/2025.07.25.666820).

6. **EpiSegMix Topology Modelling:** It includes 3 modules (`TRAIN`, `DECODE` & `REPORT`) to give us segmentation results based on topology modeling HMM.

7. **EpiSegMix Standard Modelling:** It includes 3 modules (`TRAIN`, `DECODE` & `REPORT`) to give us segmentation results based on standard modeling HMM.

8. **EpiSegMix Methylation Modelling:** It includes 3 modules (`TRAIN`, `DECODE` & `REPORT`) to give us segmentation results based on topology modeling HMM but <strong>only for coverage markers</strong>.

9. **EpiSegMix Fitting:** It includes 2 modules (`TRAIN` & `BEST_DISTRIBUTION`) to give us a new samplesheet containing the best distribution that fits our data.

---

### **Subworkflow Reference**

The pipeline logic is organized into the following modular components:

| Category            | Subworkflows                                                    |
| :------------------ | :-------------------------------------------------------------- |
| **Setup**           | `GET_CHROMSIZES`, `FILTER_CHROMSIZES`, `SORT_REFRENCE`, `MAKE_WINDOWS`, `CONFIG` & `TRAINCOUNTS`                             |
| **Data Processing** | `SAMTOOLS_REHEADER`, `SAMTOOLS_INDEX`, `BAM_SHEET`, `BAM_COUNTS`, `BED_COUTNS` & `BEDTOOLS_MAP`             |
| **Modeling**  | `TRAIN`, `DECODE` & `REPORT` |
| **Optimization**    | `BEST_DISTRIBUTION`                                          |

---

> **Note:** You can set the execution mode using flags: `--duration`, `--dna` & `--fitting` to adjust for what type of segmentation modeling you would like to use. 

**Note:** You can also directly use a your own count matrices if you have using the flags `--methcounts` & `--histonecounts`.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

_**samplesheet.csv**_:

```csv
sample_id,replicate,epigenetic_mark,file_name,modality,paired_end,distribution
Kidney,1,H3K27ac,../data/kidney/histone/kidney_H3K27ac.bam,ChIP-seq,true,NBI
Kidney,2,WGBS,../data/kidney/wgbs/kidney_WGBS.bed,WGBS,true,BI
```

Each row represents a specific assay file associated with a sample. The pipeline automatically distinguishes between histone data and methylation data based on the file extension.

### Column Specifications

- **`sample_id`**: A unique identifier for your sample (e.g., `Kidney`). Files sharing the same `sample_id` will be grouped and processed together.
- **`replicate`**: The replicate number for the sample (e.g., `1`).
- **`epigenetic_mark`**: The specific target or assay type (e.g., `H3K27ac` for histones, `WGBS` for methylation).
- **`file_name`**: The file path. Histone data must be `.bam` or `.bam.gz`. Methylation data must be `.bed` or `.bed.gz`.
- **`modality`**: The type of experiment performed (e.g., `ChIP-seq`, `WGBS`).
- **`paired_end`**: A boolean value (`true` or `false`) indicating if the sequencing data is paired-end.
- **`distribution`**: The statistical distribution to apply during model training for this mark (e.g., `NBI` for Negative Binomial, `BI` for Binomial). Leave empty to use global defaults.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/epigenomesegmentation \
   --input samplesheet.csv \
   --outdir <OUTDIR> \
   --genome hg38 \
   -profile <docker/singularity/.../institute>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/epigenomesegmentation/usage) and the [parameter documentation](https://nf-co.re/epigenomesegmentation/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/epigenomesegmentation/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/epigenomesegmentation/output).

## Credits

The original framework EpiSegMix that was used in ESM (https://doi.org/10.1093/bioinformatics/btae178) and ESMM (https://doi.org/10.1101/2025.07.25.666820) was written by Johanna Elena Schmitz and [Nihit Aggarwal](mailto:nihit.aggarwal@uni-saarland.de) (Saarland University).

The pipeline was rewritten in Nextflow DSL2 by Aaryan Jaitly (Saarland University).

**EpiSegMix tool was developed and designed by:**

- [Nihit Aggarwal](mailto:nihit.aggarwal@uni-saarland.de)
- Johanna Elena Schmitz
- Dr. AbdulRahman Salhab
- Prof. Dr. Jörn Walter
- Prof. Dr. Sven Rahmann

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#epigenomesegmentation` channel](https://nfcore.slack.com/channels/epigenomesegmentation) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
