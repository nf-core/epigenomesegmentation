process CUSTOM_BEDCOUNTS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'biocontainers/biocontainers:v1.2.0_cv1':
        'biocontainers/biocontainers:v1.2.0_cv1' }"

    input:
    tuple val(meta), path(bed)

    output:
    tuple val(meta), path("*.tab"), emit: countsbed
    tuple val("${task.process}"), val('awk'), eval("awk --version | head -n 1 | awk '{print \$3}'"), topic: versions, emit: versions_awk
    tuple val("${task.process}"), val('sort'), eval("sort --version | head -n 1 | awk '{print \$NF}'"), topic: versions, emit: versions_sort

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-s ${meta.id} -m ${meta.modality}"
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.modality}"

    """
    countsbed.sh \\
        $args \\
        -@ $task.cpus \\
        -o ${prefix}.tab \\
        -i ${bed}
    """

    stub:
    def args = task.ext.args ?: "-s ${meta.id} -m ${meta.modality}"
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.modality}"
    """
    echo $args

    touch ${prefix}.tab
    """
}
