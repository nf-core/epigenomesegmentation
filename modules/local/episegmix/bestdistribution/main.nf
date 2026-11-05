process EPISEGMIX_BESTDISTRIBUTION {
    tag "SAMPLE SHEET CREATION"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'ubuntu:22.04':
        'ubuntu:22.04' }"

    input:
    path(log)
    path(ch_samplesheet)

    output:
    path("best_samplesheet.csv"), emit: samplesheet
    path("all_parsed_loglikelihoods.tsv"), emit: results_all
    tuple val("${task.process}"), val('episegmix'), eval("episegmix --version"), topic: versions, emit: versions_episegmix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-i ${ch_samplesheet}"
    def prefix = task.ext.prefix ?: "best_samplesheet"
    """
    bestdistribution.sh \\
        $args \\
        -@ $task.cpus \\
        -o ${prefix}.csv \\
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "best_samplesheet"
    """
    echo $args

    touch ${prefix}.csv all_parsed_loglikelihoods.tsv
    """
}
