process CUSTOM_DOWNLOADCHROMSIZES {
    tag "${genome}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gnu-wget:1.18--hb829ee6_10':
        'quay.io/biocontainers/gnu-wget:1.18--hb829ee6_10' }"

    input:
    val genome

    output:
    path "*.chrom.sizes", emit: chromsizes
    tuple val("${task.process}"), val('wget'), eval("wget -V | head -n1 | cut -f 3 -d \" \""), topic: versions, emit: versions_wget

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "http://hgdownload.soe.ucsc.edu/goldenPath/${genome}/bigZips/${genome}.chrom.sizes"
    def prefix   = task.ext.prefix ?: "${genome}"

    """
    wget \\
        $args \\
        -O "${prefix}.chrom.sizes"
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix   = task.ext.prefix ?: "${genome}"

    """
    echo $args

    touch ${prefix}.chrom.sizes
    """
}
