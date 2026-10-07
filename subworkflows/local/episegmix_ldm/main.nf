include { EPISEGMIX_LDMTRAIN              } from '../../../modules/local/episegmix/ldmtrain/'
include { EPISEGMIX_LDMDECODE             } from '../../../modules/local/episegmix/ldmdecode/'
include { EPISEGMIX_LDMREPORT             } from '../../../modules/local/episegmix/ldmreport/'

workflow EPISEGMIX_LDM {

    take:
    ch_train_counts

    main:
    EPISEGMIX_LDMTRAIN(ch_train_counts)

    EPISEGMIX_LDMDECODE(EPISEGMIX_LDMTRAIN.out.json)

    EPISEGMIX_LDMREPORT(EPISEGMIX_LDMDECODE.out.Segmentation)

    emit:
    ch_segmentation = EPISEGMIX_LDMDECODE.out.Segmentation
    ch_json = EPISEGMIX_LDMTRAIN.out.json
}
