process CUSTOM_MERGECOVERAGECOUNTS {
    tag "$sample_id"
    label 'process_single'

    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'ubuntu:22.04'
        : 'ubuntu:22.04'}"

    input:
    tuple val(sample_id), val(meta), path(meth_files)

    output:
    tuple val(sample_id), val(meta), path("${sample_id}.coverage.tsv"), emit: merged

    when:
    task.ext.when == null || task.ext.when

    script:
    def coverageFiles = meth_files instanceof Collection ? meth_files : [meth_files]
    def inputFiles = coverageFiles
        .collect { it.toString().replace("'", "'\\''") }
        .collect { "'${it}'" }
        .join(' ')

    """
    set -euo pipefail

    paste ${inputFiles} | awk -v file_count=${coverageFiles.size()} '
        BEGIN {
            OFS = "\\t"
            expected_fields = file_count * 5
            printf "chr%sstart%send", OFS, OFS
            for (file = 1; file <= file_count; file++) {
                printf "%sCov%d%sMeth%d", OFS, file, OFS, file
            }
            printf "\\n"
        }
        {
            if (NF != expected_fields) {
                printf "Expected %d columns per BED count file; found %d pasted columns on row %d\\n", expected_fields, NF, FNR > "/dev/stderr"
                exit 1
            }

            for (column = 1; column <= 3; column++) {
                coordinates[column] = \$column
            }
            for (file = 1; file < file_count; file++) {
                offset = file * 5
                for (column = 1; column <= 3; column++) {
                    if (\$(offset + column) != coordinates[column]) {
                        printf "Genomic coordinates differ between BED count files on row %d\\n", FNR > "/dev/stderr"
                        exit 1
                    }
                }
            }

            printf "%s", \$1
            printf "%s%s", OFS, \$2
            printf "%s%s", OFS, \$3
            for (file = 0; file < file_count; file++) {
                first_value = file * 5 + 4
                printf "%s%s%s%s", OFS, \$(first_value), OFS, \$(first_value + 1)
            }
            printf "\\n"
        }
        END {
            if (FNR == 0) {
                print "BED count files are empty" > "/dev/stderr"
                exit 1
            }
        }
    ' > ${sample_id}.coverage.tsv
    """

    stub:
    """
    touch ${sample_id}.coverage.tsv
    """
}
