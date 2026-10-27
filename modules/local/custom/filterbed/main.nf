process CUSTOM_FILTERBED {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'ubuntu:22.04':
        'ubuntu:22.04'}"

    input:
    tuple val(meta), path(meth)

    output:
    tuple val(meta), path("*.tab"), emit: meth_tab
    tuple val("${task.process}"), val('awk'), eval("awk --version | cut -f 3 -d \" \" "), topic: versions, emit: versions_awk

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.epigenetic_mark}_${meta.replicate}"
    """
    {
    echo -e "Cov\tMeth"
    awk 'BEGIN {OFS="\t"} {print int(\$4), int(\$5)}' "${meth}"
    } > "${prefix}_meth.tab"
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.epigenetic_mark}"
    """
    echo $args

    touch ${prefix}_meth.tab
    """
}
