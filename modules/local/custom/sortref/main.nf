process CUSTOM_SORTREF {
    tag "$meta_id"
    label 'process_single'


    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04':
        'ubuntu:22.04' }"

    input:
    tuple val(meta_id), path(filtered_chromsizes)


    output:
    tuple val (meta_id), path("${filtered_chromsizes}.v2"), emit: filtered_chromsizes
    tuple val("${task.process}"), val('awk'), eval("awk --version | cut -f 3 -d \" \" "), topic: versions, emit: versions_awk
    tuple val("${task.process}"), val('sort'), eval("sort --version | head -n 1 | awk '{print \$NF}'"), topic: versions, emit: versions_sort

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "sort -k1,1V | awk -vOFS=\"\\t\" '{print \$1, 1, \$2}'"
    def prefix = task.ext.prefix ?: "${filtered_chromsizes}"

    """
    cat ${filtered_chromsizes} | $args > ${prefix}.v2
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${filtered_chromsizes}"

    """
    echo $args

    touch ${prefix}.v2
    """
}
