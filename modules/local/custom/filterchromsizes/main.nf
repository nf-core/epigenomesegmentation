process CUSTOM_FILTERCHROMSIZES {
    tag "${params.genome}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04':
        'ubuntu:22.04' }"

    input:
    path chromsizes

    output:
    tuple val (params.genome), path("filtered_${chromsizes}"), emit: filtered_chromsizes
    tuple val("${task.process}"), val('sort'), eval("sort --version | head -n 1 | awk '{print \$NF}'"), topic: versions, emit: versions_sort
    tuple val("${task.process}"), val('awk'), eval("awk --version | head -n 1 | awk '{print \$3}'"), topic: versions, emit: versions_awk

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '-v OFS="\\t" \'$1 ~ /^chr([1-9][0-9]?|X|Y)$/ { sub(/^chr/, "", $1); print}\''
    def prefix   = task.ext.prefix ?: "${chromsizes}"

    """
    awk \\
        $args \\
        ${chromsizes} | sort -k1,1V > "filtered_${prefix}"
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${chromsizes}"

    """
    echo $args

    touch "filtered_${prefix}"
    """
}
