process EPISEGMIX_LDMREPORT {
    tag "$sample_id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'aaryanjaitly/episegmix_v2:latest':
        'aaryanjaitly/episegmix_v2:latest' }"

    input:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml), path(traincounts), path(trainregions), path(traincountsmeth), path(json), path(segmentation)

    output:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml), path(traincounts), path(trainregions), path(traincountsmeth), path(json), path(segmentation), path("Plots/*"), emit: Segmentation
    tuple val("${task.process}"), val('episegmix'), eval("episegmix --version"), topic: versions, emit: versions_episegmix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-y ${yaml} -j ${json} -s ${segmentation}"
    def prefix = task.ext.prefix ?: "${sample_id}"

    """
    ldmreport.sh \\
        $args \\
        -@ $task.cpus \\
        -o ${prefix} \\
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo $args

    mkdir Plots
    touch Plots/dummy.txt
    """
}