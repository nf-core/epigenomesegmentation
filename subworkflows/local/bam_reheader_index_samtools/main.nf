include { SAMTOOLS_REHEADER      } from '../../../modules/nf-core/samtools/reheader/main'
include { SAMTOOLS_INDEX     } from '../../../modules/nf-core/samtools/index/main'

workflow BAM_REHEADER_INDEX_SAMTOOLS {

    take:
    ch_bam

    main:
    ch_versions = Channel.empty()

    ch_bam_new = ch_bam.map { meta, bam ->
        [meta, bam, []]
    }
    SAMTOOLS_REHEADER(ch_bam_new)
    SAMTOOLS_INDEX(SAMTOOLS_REHEADER.out.bam)

    emit:
    bam      = SAMTOOLS_REHEADER.out.bam
    bai      = SAMTOOLS_INDEX.out.index
    versions = ch_versions
}
