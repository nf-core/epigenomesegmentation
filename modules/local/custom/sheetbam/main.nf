process CUSTOM_SHEETBAM {
    tag "$sample_id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:4.1.3--1':
        'quay.io/biocontainers/gawk:4.1.3--1' }"

    input:
    tuple val(sample_id) ,val(meta), path(bam), path(bai)

    output:
    tuple val(sample_id) ,val(meta), path("*.txt"), path(bam), emit: sheetbam
    tuple val("${task.process}"), val('awk'), eval("awk --version | head -n1 | cut -d \" \" -f 3"), topic: versions, emit: versions_awk

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-h \"${meta.epigenetic_mark}\" -p \"${meta.paired_end}\""
    def prefix = task.ext.prefix ?: "${sample_id}"

    """
    sheetbam.sh \\
        $args \\
        -o ${prefix}.txt \\
        -b "$bam"
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}"
    """
    echo $args

    touch ${prefix}.txt
    """
}
