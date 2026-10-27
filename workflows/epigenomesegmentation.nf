/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_epigenomesegmentation_pipeline'

// Subworkflow
include { PREPARE_GENOME                  } from '../subworkflows/local/prepare_genome/'
include { BAM_REHEADER_INDEX_SAMTOOLS     } from '../subworkflows/local/bam_reheader_index_samtools/'
include { TAB_SHEETBAM_COUNTSBAM_CUSTOM   } from '../subworkflows/local/tab_sheetbam_countsbam_custom/'
include { BED_COUNTS                      } from '../subworkflows/local/bed_counts/'
include { MERGE                           } from '../subworkflows/local/merge/'
include { EPISEGMIX_PREPARE               } from '../subworkflows/local/episegmix_prepare/'
include { EPISEGMIX_LDM                   } from '../subworkflows/local/episegmix_ldm/'
include { EPISEGMIX_DM                    } from '../subworkflows/local/episegmix_dm/'
include { EPISEGMIX_DNA                   } from '../subworkflows/local/episegmix_dna/'
include { EPISEGMIX_FITTING               } from '../subworkflows/local/episegmix_fitting/'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EPIGENOMESEGMENTATION {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    outdir

    main:

    def ch_versions = Channel.empty()

    // --- PIPELINE LOGIC ---

    ch_samplesheet
        .branch { it ->
            bam:   it[1].toString().toLowerCase().endsWith('.bam') || it[1].toString().toLowerCase().endsWith('.bam.gz')
            bed:   it[1].toString().toLowerCase().endsWith('.bed') || it[1].toString().toLowerCase().endsWith('.bed.gz')
            other: true
        }
        .set { ch_input_branched }

    if(params.dna){
        ch_in_bam_reheader = Channel.empty()
    }
    else{
        ch_in_bam_reheader = ch_input_branched.bam
    }
    ch_in_bedcounts    = ch_input_branched.bed


    if (params.histonecounts && params.methcounts) {

        ch_histonecounts = Channel.fromPath(params.histonecounts).first()
        ch_methcounts    = Channel.fromPath(params.methcounts).first()
        ch_bamcounts = ch_input_branched.bam
            .map { meta, bamfile -> [meta.id, meta] }
            .groupTuple()
            .map { sample_id, meta_list -> [sample_id, meta_list] }
            .combine(ch_histonecounts)

        // 3. Same logic for the BED channel
        ch_meth_tab = ch_input_branched.bed
            .map { meta, bedfile -> [meta.id, meta] }
            .groupTuple(by: 0)
            .combine(ch_methcounts)

    }

    else if (params.histonecounts) {

        ch_histonecounts = Channel.fromPath(params.histonecounts).first()
        ch_bamcounts = ch_input_branched.bam
            .map { meta, bamfile -> [meta.id, meta] }
            .groupTuple()
            .map { sample_id, meta_list -> [sample_id, meta_list] }
            .combine(ch_histonecounts)
            
        ch_meth_tab =  Channel.empty()

    }


    else if (params.methcounts && params.dna) {

        ch_methcounts = Channel.fromPath(params.methcounts).first()
        ch_mapped_bed = ch_input_branched.bed
            .map { meta, bedfile -> [meta.id, meta] }
            .groupTuple(by: 0)
            .combine(ch_methcounts)
    }


    else{


        PREPARE_GENOME()
        ch_chrom_sizes_sort = PREPARE_GENOME.out.chrom_sizes_sort
        ch_bins             = PREPARE_GENOME.out.bins

        BAM_REHEADER_INDEX_SAMTOOLS(ch_in_bam_reheader)
        ch_bam      = BAM_REHEADER_INDEX_SAMTOOLS.out.bam
        ch_bai      = BAM_REHEADER_INDEX_SAMTOOLS.out.bai
        BED_COUNTS(ch_in_bedcounts, ch_bins)
        ch_mapped_bed = BED_COUNTS.out.ch_mapped_bed


        TAB_SHEETBAM_COUNTSBAM_CUSTOM(ch_bam, ch_bai, ch_chrom_sizes_sort)
        ch_bamcounts = TAB_SHEETBAM_COUNTSBAM_CUSTOM.out.bamcounts

        ch_merge = ch_bamcounts.combine(ch_mapped_bed, by: 0)

        MERGE(ch_merge)
        ch_meth_tab = MERGE.out.ch_meth_tab_new

    }


    ch_states = Channel.of("${params.states}").splitCsv().flatten()

    if (params.dna == true) {
        ch_in_episegmix_config = ch_mapped_bed
        .map { it ->
            def sample_id = it[0]
            def meta2     = it[1]
            def meth      = it[2]

            def meta1     = [id: 'no_bam_counts']
            def histone   = []

            return tuple(sample_id, meta1, histone, meta2, meth)
        }
        .combine(ch_states)
        .map { sample_id, meta1, histone, meta2, meth, state ->
            ["${sample_id}_${state}", meta1, histone, meta2, meth, state]
        }
    }
    else if (params.fitting == true) {
        ch_dist = Channel.of("${params.distributions}").splitCsv().flatten()

        ch_in_episegmix_config = ch_bamcounts
            .join(ch_meth_tab, remainder: true)
            .map { it ->
                def sample_id = it[0]
                def meta1
                def histone
                def meta2
                def meth

                if (it.size() == 4 && it[1] != null) {
                    meta1 = it[1]; histone = it[2]
                    meta2 = [id: sample_id]; meth = null
                }
                else if (it.size() == 4 && it[1] == null) {
                    meta2 = it[2]; meth = it[3]
                    // WRAP IN LIST: transpose() requires a list, even if it's just 1 item.
                    meta1 = [[id: sample_id, epigenetic_mark: meta2.epigenetic_mark ?: 'UNKNOWN_MARK']]
                    histone = null
                }
                else {
                    meta1 = it[1]; histone = it[2]
                    meta2 = it[3]; meth = it[4]
                }

                if (meta2 instanceof List && meta2.size() == 1) {
                    meta2 = meta2[0]
                }

                return tuple(sample_id, meta1, histone, meta2, meth)
            }
            .combine(ch_states)
            .transpose()
            .combine(ch_dist)
            .map { sample_id, meta1, histone, meta2, meth, state, dist ->
                def explicit_meta = [
                    id: meta1.id,
                    epigenetic_mark: meta1.epigenetic_mark,
                    distribution: dist
                ]
                return tuple(
                    "${meta1.id}_${dist}_${state}_${meta1.epigenetic_mark}",
                    explicit_meta,
                    histone,
                    explicit_meta,
                    [],
                    state
                )
            }
    }
    else if (params.counts) {
        ch_in_episegmix_config = Channel.empty()
    }
    else if (params.jointrain) {
        ch_in_episegmix_config = ch_bamcounts
            .join(ch_meth_tab, remainder: true)
            .map { it ->
                def sample_id = it[0]
                def meta1
                def histone
                def meta2
                def meth

                if (it.size() == 4 && it[1] != null) {
                    meta1 = it[1]
                    histone = it[2]
                    meta2 = [id: 'no_bed_counts']
                    meth = []
                }
                else if (it.size() == 4 && it[1] == null) {
                    meta1 = [id: 'no_bam_counts']
                    histone = []
                    meta2 = it[2]
                    meth = it[3]
                }
                else {
                    meta1 = it[1]
                    histone = it[2]
                    meta2 = it[3]
                    meth = it[4]
                }

                return tuple(sample_id, meta1, histone, meta2, meth)
            }
            .combine(ch_states)
                        .map { sample_id, meta1, histone, meta2, meth, state ->
                            [state, sample_id, meta1, histone, meta2, meth]
                        }
                        .groupTuple()
                        .map { state, sample_ids, meta1, histone, meta2, meth ->
                            def combined_key = "${sample_ids.join('_')}_${state}"

                            def histone_files = histone.flatten().findAll { it != null }
                            def meth_files = meth.flatten().findAll { it != null }

                            [combined_key, meta1[0], histone_files, meta2[0], meth_files, state]
                        }
    }
    else {

        ch_in_episegmix_config = ch_bamcounts
            .join(ch_meth_tab, remainder: true)
            .map { it ->
                def sample_id = it[0]
                def meta1
                def histone
                def meta2
                def meth

                if (it.size() == 4 && it[1] != null) {
                    meta1 = it[1]
                    histone = it[2]
                    meta2 = [id: 'no_bed_counts']
                    meth = []
                }
                else if (it.size() == 4 && it[1] == null) {
                    meta1 = [id: 'no_bam_counts']
                    histone = []
                    meta2 = it[2]
                    meth = it[3]
                }
                else {
                    meta1 = it[1]
                    histone = it[2]
                    meta2 = it[3]
                    meth = it[4]
                }

                return tuple(sample_id, meta1, histone, meta2, meth)
            }
            .combine(ch_states)
            .map { sample_id, meta1, histone, meta2, meth, state ->
                ["${sample_id}_${state}", meta1, histone, meta2, meth, state]
            }
    }


    EPISEGMIX_PREPARE(ch_in_episegmix_config)

    ch_train_counts = EPISEGMIX_PREPARE.out.ch_train_counts
    ch_train_region = EPISEGMIX_PREPARE.out.ch_dna_regions

    if (params.duration == true) {
        EPISEGMIX_DM(ch_train_counts)
    }
    else if (params.dna == true) {
        EPISEGMIX_DNA(ch_train_counts, ch_train_region)
    }
    else if (params.fitting == true) {
        EPISEGMIX_FITTING(ch_train_counts)
    }
    else {
        EPISEGMIX_LDM(ch_train_counts)
    }

    // --- VERSION COLLATION ---

    // Collate and save software versions
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'epigenomesegmentation_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    emit:
    versions = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
