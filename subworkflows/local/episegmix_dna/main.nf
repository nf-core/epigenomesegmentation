include { EPISEGMIX_DNATRAIN             } from '../../../modules/local/episegmix/dnatrain/'
include { EPISEGMIX_DNADECODE             } from '../../../modules/local/episegmix/dnadecode/'
include { EPISEGMIX_DNAREPORT             } from '../../../modules/local/episegmix/dnareport/'

workflow EPISEGMIX_DNA {

    take:
    ch_train_counts
    ch_train_region


    main:

    EPISEGMIX_DNATRAIN(ch_train_counts)
    ch_dnatrain_json = EPISEGMIX_DNATRAIN.out.json
    ch_in_episegmix_decode = ch_dnatrain_json.join(ch_train_region)


    EPISEGMIX_DNADECODE(ch_in_episegmix_decode)
    ch_segmentation = EPISEGMIX_DNADECODE.out.Segmentation
    EPISEGMIX_DNAREPORT(ch_segmentation)

    emit:
    ch_segmentation = EPISEGMIX_DNADECODE.out.Segmentation
    ch_dnatrain_json = EPISEGMIX_DNATRAIN.out.json

}
