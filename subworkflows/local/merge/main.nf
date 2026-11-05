include { CUSTOM_STRIPHEADER      } from '../../../modules/local/custom/stripheader/'
include { BEDTOOLS_INTERSECT      } from '../../../modules/nf-core/bedtools/intersect/'
include { CUSTOM_FILTERBED                } from '../../../modules/local/custom/filterbed/'
include { CUSTOM_JOINBED                   } from '../../../modules/local/custom/joinbed/'


workflow MERGE {

    take:
    ch_merge

    main:

    ch_in_stripheader = ch_merge.map{
        sample_id, meta1, histone, meta3 , binned ->
        [
        [id: sample_id],
        histone
        ]
    }

    CUSTOM_STRIPHEADER(ch_in_stripheader)

    ch_merge_new = ch_merge.join(CUSTOM_STRIPHEADER.out.noheader)

    ch_bed_in = ch_merge_new
    .map{
        sample_id, meta1, histone, meta3, binned, noheaderhistone ->
        [
        meta3,
        binned,
        noheaderhistone
        ]
    }

    ch_chrom_dummy = Channel.value([ [id: "DUMMY"], [] ])


    BEDTOOLS_INTERSECT(ch_bed_in,ch_chrom_dummy)

    CUSTOM_FILTERBED(BEDTOOLS_INTERSECT.out.intersect)

    ch_meth_tab = CUSTOM_FILTERBED.out.meth_tab.map{
        meta, meth_tab ->
        [meta.id, meta, meth_tab]
    }
    ch_join_bed = ch_meth_tab.groupTuple(by: 0)

    CUSTOM_JOINBED(ch_join_bed)

    ch_meth_tab_new = CUSTOM_JOINBED.out.joined_ch_tab

    emit:
    ch_meth_tab_new

}
