include { EPISEGMIX_LDMTRAIN             } from '../../../modules/local/episegmix/ldmtrain/'
include { EPISEGMIX_BESTDISTRIBUTION      } from '../../../modules/local/episegmix/bestdistribution/'

workflow EPISEGMIX_FITTING {

    take:
    ch_train_counts

    main:
    EPISEGMIX_LDMTRAIN(ch_train_counts)
    ch_all_logs = EPISEGMIX_LDMTRAIN.out.log
    .map { sample_id, log -> log }
    .collect()

    ch_input = Channel.fromPath(params.input)

    EPISEGMIX_BESTDISTRIBUTION(ch_all_logs, ch_input)

    emit:
    EPISEGMIX_BESTDISTRIBUTION.out.samplesheet
}
