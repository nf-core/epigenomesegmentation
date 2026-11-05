process CUSTOM_JOINBED {
    tag "$sample_id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04':
        'ubuntu:22.04' }"

    input:
    tuple val(sample_id), val(meta), path(meth_tab)

    output:
    tuple val(sample_id), val(meta), path("${sample_id}_meth.tab*"), emit: joined_ch_tab

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}_meth.tab"
    """
        paste *_meth.tab > $prefix
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}_meth.tab"
    """
    echo $args

    touch ${prefix}
    """
}
