process EPISEGMIX_CONFIG {
    tag "${sample_id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'ubuntu:22.04':
        'ubuntu:22.04' }"

    input:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state)

    output:
    tuple val(sample_id), val(meta), path(histone), val(meta2), path(meth), val(state), path("*.yaml"), emit: yaml
    tuple val("${task.process}"), val('episegmix'), eval("episegmix --version"), topic: versions, emit: versions_episegmix

    when:
    task.ext.when == null || task.ext.when

    script:
    // Define arguments with robust collection handling
    def args = task.ext.args ?: "-s ${state} -c ${params.chr_parameter_estimation}"

    // Methylation files (-g)
    def meth_file = meth
        ? "-g \"${meth instanceof Collection ? meth.join(', ') : meth}\""
        : '-g null'

    // Histone files (-h)
    def histone_file = histone
        ? "-h \"${histone instanceof Collection ? histone.join(', ') : histone}\""
        : '-h null'

    // Epigenetic marks (-m)
    def epimark = meta.epigenetic_mark
        ? "-m \"${meta.epigenetic_mark instanceof Collection ? meta.epigenetic_mark.join(' ') : meta.epigenetic_mark}\""
        : '-m null'

    // meth marks (-m)
    def methmark = meta2.epigenetic_mark
        ? "-x \"${meta2.epigenetic_mark instanceof Collection ? meta2.epigenetic_mark.join(' ') : meta2.epigenetic_mark}\""
        : '-x null'

    // Methylation distribution (-d for methylation - assuming a specific meta key)
    def meth_dist = meta2.distribution
        ? "-n \"${meta2.distribution instanceof Collection ? meta2.distribution.join(' ') : meta2.distribution}\""
        : '-n null'

    // Histone distribution (-d for histone)
    def his_dist = meta.distribution
        ? "-d \"${meta.distribution instanceof Collection ? meta.distribution.join(' ') : meta.distribution}\""
        : '-d null'

    // Output prefix
    def prefix = task.ext.prefix ?: "${sample_id}"

    """
    episegmix_config.sh \\
         $args \\
         ${epimark} \\
         ${his_dist} \\
         ${meth_file} \\
         ${methmark} \\
         ${meth_dist} \\
         -o ${prefix}.yaml \\
         ${histone_file}

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${sample_id}"
    """
    echo $args

    touch ${prefix}.yaml
    """
}
