// comes from nf-test to store json files
params.nf_test_output  = ""

// include dependencies


// include test process
include { CUSTOM_JOINBED } from '/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/modules/local/custom/joinbed/tests/../main.nf'

workflow {

    // define custom rules for JSON that will be generated.
    def jsonOutput = createJsonOutput()
    def jsonWorkflowOutput = createJsonWorkflowOutput()

    def input = []

    // run dependencies
    

    // process mapping
    input = []
    
                input[0] = [
                    'GM12878',
                    [
                        [
                            id: 'GM12878',
                            replicate: 1,
                            epigenetic_mark: 'WGBS',
                            modality: 'WGBS',
                            paired_end: true,
                            distribution: 'BI'
                        ]
                    ],
                    [
                        file("/jmsh/projects/students/aaryanjaitly/nf-core/epigenomesegmentation/assets/testdata/joinbed/GM12878_WGBS_1_meth.tab", checkIfExists: true)
                    ]
                ]
                
    //----

    //run process
    CUSTOM_JOINBED.run(input.toArray())

    if (CUSTOM_JOINBED.output){

        // consumes all named output channels and stores items in a json file
        CUSTOM_JOINBED.out.getNames().each { name ->
            serializeChannel(name, CUSTOM_JOINBED.out.getProperty(name), jsonOutput, params.nf_test_output)
        }	  

        // consumes all unnamed output channels and stores items in a json file
        def array = CUSTOM_JOINBED.out as List<Object>
        def i = 0
        array.each { output ->
            serializeChannel(i, output, jsonOutput, params.nf_test_output)
            i += 1
        }    	

    }

    // get topics

    // finalize test
    workflow.onComplete = {
        def result = [
            success: workflow.success,
            exitStatus: workflow.exitStatus,
            errorMessage: workflow.errorMessage,
            errorReport: workflow.errorReport
        ]
        new File("${params.nf_test_output}/workflow.json").text = jsonWorkflowOutput.toJson(result)
        
    }
}

def serializeChannel(name, channel, jsonOutput, outputDir) {
    def _name = name
    def list = [ ]
    channel.subscribe(
        onNext: { entry ->
            list.add(entry)
        },
        onComplete: {
            def map = new HashMap()
            map[_name] = list
            def filename = "${outputDir}/output_${_name}.json"
            new File(filename).text = jsonOutput.toJson(map)		  		
        } 
    )
}

def serializeTopic(name, topic, jsonOutput, outputDir) {
    def list = [ ]
    topic.subscribe(
        onNext: { entry ->
            list.add(entry)
        },
        onComplete: {
            def map = new HashMap()
            map[name] = list
            def filename = "${outputDir}/topic_${name}.json"
            new File(filename).text = jsonOutput.toJson(map)		  		
        } 
    )
}

def createJsonOutput(_input = null) {
    // _input is needed because a closure is provided to all functions called in the process
    return [
        toJson: { obj ->
            def converted = convertPathsToStrings(obj)
            return groovy.json.JsonOutput.toJson(converted)
        }
    ]
}

def convertPathsToStrings(obj) {
    if (obj instanceof java.nio.file.Path) {
        return obj.toAbsolutePath().toString()
    } else if (obj instanceof Map) {
        return obj.collectEntries { k, v -> [k, convertPathsToStrings(v)] }
    } else if (obj instanceof Collection) {
        return obj.collect { it -> convertPathsToStrings(it) }
    } else {
        return obj
    }
}

def createJsonWorkflowOutput(_input = null) {
    // _input is needed because a closure is provided to all functions called in the workflow
    return [
        toJson: { obj ->
            def filtered = removeNullValues(obj)
            return groovy.json.JsonOutput.toJson(filtered)
        }
    ]
}

def removeNullValues(obj) {
    if (obj instanceof Map) {
        return obj.findAll { _k, v -> v != null }.collectEntries { k, v -> [k, removeNullValues(v)] }
    } else if (obj instanceof Collection) {
        return obj.findAll { it -> it != null }.collect { it -> removeNullValues(it) }
    } else {
        return obj
    }
}