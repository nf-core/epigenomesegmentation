include { EPISEGMIX_DMTRAIN              } from '../../../modules/local/episegmix/dmtrain/'
include { EPISEGMIX_DMDECODE             } from '../../../modules/local/episegmix/dmdecode/'
include { EPISEGMIX_DMREPORT             } from '../../../modules/local/episegmix/dmreport/'

workflow EPISEGMIX_DM {

    take:
    ch_train_counts

    main:
        EPISEGMIX_DMTRAIN(ch_train_counts)
        EPISEGMIX_DMDECODE(EPISEGMIX_DMTRAIN.out.json)
        EPISEGMIX_DMREPORT(EPISEGMIX_DMDECODE.out.Segmentation)

    emit:
    ch_segmentation = EPISEGMIX_DMDECODE.out.Segmentation
    ch_dmtrain_json = EPISEGMIX_DMTRAIN.out.json
}
