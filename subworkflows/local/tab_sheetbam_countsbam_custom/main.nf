include { CUSTOM_SHEETBAM      } from '../../../modules/local/custom/sheetbam/main'
include { CUSTOM_BAMCOUNTS } from '../../../modules/local/custom/bamcounts/main'


workflow TAB_SHEETBAM_COUNTSBAM_CUSTOM {

    take:
    ch_bam
    ch_bai
    ch_ref

    main:

    ch_in_bam_counts = ch_bam
        .join(ch_bai)
        .map { meta, bam, bai ->
            [ meta.id, meta, bam, bai ]
        }
        .groupTuple()

    CUSTOM_SHEETBAM ( ch_in_bam_counts )
    CUSTOM_BAMCOUNTS( CUSTOM_SHEETBAM.out.sheetbam, ch_ref)

    emit:
    sheetbam = CUSTOM_SHEETBAM.out.sheetbam
    bamcounts = CUSTOM_BAMCOUNTS.out.bamcounts
}
