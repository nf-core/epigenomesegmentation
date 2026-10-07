include { CUSTOM_DOWNLOADCHROMSIZES } from '../../../modules/local/custom/downloadchromsizes/main'
include { CUSTOM_FILTERCHROMSIZES   } from '../../../modules/local/custom/filterchromsizes/main'
include { BEDTOOLS_MAKEWINDOWS      } from '../../../modules/nf-core/bedtools/makewindows/main'
include { CUSTOM_FILTERBINS } from '../../../modules/local/custom/filterbins/main'
include { CUSTOM_SORTREF } from '../../../modules/local/custom/sortref/main'
workflow PREPARE_GENOME {
    main:
    ch_versions = Channel.empty()

    // 1. CONDITIONAL: Download or use provided chromsizes
    if (!params.chromsizes) {
        // Scenario A (3 runs): No file provided, so we download it first
        CUSTOM_DOWNLOADCHROMSIZES(
            params.genome
        )
        ch_raw_chromsizes = CUSTOM_DOWNLOADCHROMSIZES.out.chromsizes
    } else {
        // Scenario B (2 runs): File is provided, skip download and convert string to a file channel
        ch_raw_chromsizes = Channel.fromPath(params.chromsizes)
    }

    // 2. FILTER: Run the filter module on whichever channel was created above
    CUSTOM_FILTERCHROMSIZES(
        ch_raw_chromsizes
    )

    ch_for_makewindows = CUSTOM_FILTERCHROMSIZES.out.filtered_chromsizes.map {genome, chromsizes ->
        def meta = [id: genome]
        return [meta, chromsizes]
    }

    // 3. BIN: Create fixed-size genomic windows from the filtered sizes
    BEDTOOLS_MAKEWINDOWS(ch_for_makewindows)

    // Filter: filter bins that are not of binsized meaning removal of termainl bins where size != params.binsize
    CUSTOM_FILTERBINS(BEDTOOLS_MAKEWINDOWS.out.bed)

    CUSTOM_SORTREF(CUSTOM_FILTERCHROMSIZES.out.filtered_chromsizes)


    emit:
    // Emit the filtered sizes and bins for downstream use
    chrom_sizes = CUSTOM_FILTERCHROMSIZES.out.filtered_chromsizes
    chrom_sizes_sort = CUSTOM_SORTREF.out.filtered_chromsizes
    bins        = CUSTOM_FILTERBINS.out.bed
    versions    = ch_versions
}
