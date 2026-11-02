include { CUSTOM_BEDCOUNTS                } from '../../../modules/local/custom/bedcounts/main'
include { BEDTOOLS_MAP                    } from '../../../modules/nf-core/bedtools/map/main'

workflow BED_COUNTS {

    take:
    ch_in_bedcounts
    ch_bins

    main:
    // ---------------------------------------------------------
    // STEP 4: BED COUNTS & MAPPING
    // ---------------------------------------------------------
    CUSTOM_BEDCOUNTS(ch_in_bedcounts)

    ch_bedcounts_out = CUSTOM_BEDCOUNTS.out.countsbed
    ch_in_bedtools_map = ch_bins
        .combine(ch_bedcounts_out)
        .map { meta1, chrombin, meta2, tab ->
            def map_meta = meta2
            if (params.dna) {
                map_meta = meta2 + [
                    sample_id: meta2.id,
                    id: "${meta2.id}_${meta2.epigenetic_mark}_${meta2.replicate ?: 1}"
                ]
            }
            [ map_meta, chrombin, tab ]
        }
    ch_dummy_chrom_sizes = Channel.value([ [id: 'dummy'], [] ])

    BEDTOOLS_MAP(ch_in_bedtools_map, ch_dummy_chrom_sizes)

    new_mapped =  BEDTOOLS_MAP.out.mapped
        .map { meta, bed ->
            def sample_id = params.dna ? (meta.sample_id ?: meta.id) : meta.id
            def restored_meta = meta
            if (params.dna) {
                restored_meta = new LinkedHashMap(meta)
                restored_meta.remove('sample_id')
                restored_meta.id = sample_id
            }
            [sample_id, restored_meta, bed]
        }
    emit:

    ch_mapped_bed = new_mapped
}
