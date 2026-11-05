process CUSTOM_FILTERBINS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:4.1.3--0':
        'quay.io/biocontainers/gawk:4.1.3--0' }"

    input:
    tuple val(meta), path(bed)

    output:
    tuple val(meta), path("filtered_*.bed"), emit: bed
    tuple val("${task.process}"), val('awk'), eval("awk --version | head -n1 | cut -d \" \" -f 3"), topic: versions, emit: versions_awk

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: " -v OFS=\"\\t\" -v size=\"${params.binsize}\" '(\$3-\$2) == size' "
    def prefix = task.ext.prefix ?: "filtered_${bed}"


    """
    awk \\
        $args \\
        $bed > tmp && mv tmp ${prefix}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "filtered_${bed}"

    """
    echo $args

    touch ${prefix}
    """
}
