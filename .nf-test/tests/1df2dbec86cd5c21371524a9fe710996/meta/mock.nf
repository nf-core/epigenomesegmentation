import groovy.json.JsonGenerator
import groovy.json.JsonGenerator.Converter

nextflow.enable.dsl=2

// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies


// include test process
include { CUSTOM_BAMCOUNTS } from '/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/modules/local/custom/bamcounts/tests/../main.nf'

// define custom rules for JSON that will be generated.
def jsonOutput =
    new JsonGenerator.Options()
        .addConverter(Path) { value -> value.toAbsolutePath().toString() } // Custom converter for Path. Only filename
        .build()

def jsonWorkflowOutput = new JsonGenerator.Options().excludeNulls().build()


workflow {

    // run dependencies
    

    // process mapping
    def input = []
    
                input[0] = [
                    'GM12878',
                    [
                        id: 'GM12878',
                        replicate: 1,
                        epigenetic_mark: 'H3K27me3',
                        modality: 'ChIP-seq',
                        paired_end: false,
                        distribution: 'NBI'
                    ],
                    file("/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/assets/testdata/results_ldm/Counts/GM12878_Histone/GM12878.txt", checkIfExists: true),
                    [
                        file("/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/assets/testdata/bamcounts/ENCFF633BHN_chr12_chr13.nochr.bam", checkIfExists: true),
                        file("/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/assets/testdata/bamcounts/ENCFF911YNM_chr12_chr13.nochr.bam", checkIfExists: true)
                    ]
                ]

                input[1] = [
                    'hg38',
                    file("/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/assets/testdata/results_ldm/References/hg38/filtered_hg38_chr12_chr13.chrom.sizes.v2", checkIfExists: true)
                ]
                
    //----

    //run process
    CUSTOM_BAMCOUNTS(*input)

    if (CUSTOM_BAMCOUNTS.output){

        // consumes all named output channels and stores items in a json file
        for (def name in CUSTOM_BAMCOUNTS.out.getNames()) {
            serializeChannel(name, CUSTOM_BAMCOUNTS.out.getProperty(name), jsonOutput)
        }	  
      
        // consumes all unnamed output channels and stores items in a json file
        def array = CUSTOM_BAMCOUNTS.out as Object[]
        for (def i = 0; i < array.length ; i++) {
            serializeChannel(i, array[i], jsonOutput)
        }    	

    }
  
}

def serializeChannel(name, channel, jsonOutput) {
    def _name = name
    def list = [ ]
    channel.subscribe(
        onNext: {
            list.add(it)
        },
        onComplete: {
              def map = new HashMap()
              map[_name] = list
              def filename = "${params.nf_test_output}/output_${_name}.json"
              new File(filename).text = jsonOutput.toJson(map)		  		
        } 
    )
}


workflow.onComplete {

    def result = [
        success: workflow.success,
        exitStatus: workflow.exitStatus,
        errorMessage: workflow.errorMessage,
        errorReport: workflow.errorReport
    ]
    new File("${params.nf_test_output}/workflow.json").text = jsonWorkflowOutput.toJson(result)
    
}
