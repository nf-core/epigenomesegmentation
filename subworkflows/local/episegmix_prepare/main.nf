include { EPISEGMIX_CONFIG                } from '../../../modules/local/episegmix/config/'
include { EPISEGMIX_TRAINCOUNTS           } from '../../../modules/local/episegmix/traincounts/'

workflow EPISEGMIX_PREPARE {

    take:
    ch_in_episegmix_config

    main:

    EPISEGMIX_CONFIG(ch_in_episegmix_config)
    EPISEGMIX_TRAINCOUNTS(EPISEGMIX_CONFIG.out.yaml)

    emit:
    ch_train_counts = EPISEGMIX_TRAINCOUNTS.out.train_counts
    ch_dna_regions = EPISEGMIX_TRAINCOUNTS.out.dna_regions
}
