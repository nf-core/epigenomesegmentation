process EPISEGMIX_LDMTRAIN {
    tag "$sample_id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'aaryanjaitly/episegmix_v2:latest':
        'aaryanjaitly/episegmix_v2:latest' }"

    input:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml) , path(traincounts), path(trainregions),  path(traincountsmeth)

    output:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml) , path(traincounts), path(trainregions),  path(traincountsmeth), path("final*.json"), emit: json
    tuple val(sample_id), path("*.log"), emit: log
    tuple val("${task.process}"), val('episegmix'), eval("episegmix --version"), topic: versions, emit: versions_episegmix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-c ${traincounts} -m ${traincountsmeth} -r ${trainregions} -y ${yaml} -a ${params.adjustment} -i ${params.iter} -e ${params.epsilon}"
    def prefix = task.ext.prefix ?: "${sample_id}"
    """
    ldmtrain.sh \\
        $args \\
        -@ $task.cpus \\
        -o ${prefix}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}"
    """
    echo $args

    touch "final-${prefix}.json"
    touch "final-${prefix}.log"
    """
}
