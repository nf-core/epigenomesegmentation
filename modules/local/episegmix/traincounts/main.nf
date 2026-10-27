process EPISEGMIX_TRAINCOUNTS {
    tag "${sample_id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'aaryanjaitly/episegmix_v2:latest':
        'aaryanjaitly/episegmix_v2:latest' }"

    input:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml)

    output:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path(yaml) ,path("*train-counts.txt"), path("*train-regions.txt"), path("*train-counts-meth.txt", optional: true), emit: train_counts
    tuple val(sample_id), path("*.regions.txt", optional: true), emit: dna_regions
    tuple val("${task.process}"), val('episegmix'), eval("episegmix --version"), topic: versions, emit: versions_episegmix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}"

    """
    if [[ "${histone}" == "" ]]; then

    awk 'BEGIN {OFS="\t"} { \$4 = int(\$4 + 0.5); \$5 = int(\$5 + 0.5); print \$0 }' $meth > tmp.bed && mv tmp.bed $meth
    sed -i '1 i\\chr\\tstart\\tend\\tCov\\tMeth' $meth

        get_meth_counts.py \\
            -d "${prefix}.yaml" \\
            -c "${prefix}-train-counts.txt" \\
            -r "${prefix}-train-regions.txt" \\
            -C "${prefix}.counts.txt" \\
            -R "${prefix}.regions.txt"
        touch "dummy-train-counts-meth.txt"
    else
        get_counts.py \\
            -d "${prefix}.yaml" \\
            -c "${prefix}-train-counts.txt" \\
            -m "${prefix}-train-counts-meth.txt" \\
            -r "${prefix}-train-regions.txt"
        touch "dummy.regions.txt"
    fi

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}"
    """
    echo $args

    touch "${prefix}.regions.txt" \\
    "${prefix}-train-counts.txt" \\
    "${prefix}-train-counts-meth.txt" \\
    "${prefix}-train-regions.txt"

    """
}
