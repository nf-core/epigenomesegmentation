process CUSTOM_STRIPHEADER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:8.25--0':
        'quay.io/biocontainers/coreutils:8.25--0' }"

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta.id), path("no_header_*"), emit: noheader
    tuple val("${task.process}"), val('tail'), eval("tail --version | head -n1 | cut -d \" \" -f 4"), topic: versions, emit: versions_tail

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    tail -n +2 ${file} > no_header_${prefix}.bed
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    touch no_header_${prefix}.bed
    """
}
