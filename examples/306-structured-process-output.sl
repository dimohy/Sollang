import sys.file as file
import sys.process as process

main {
    process.arguments => arguments
    arguments -> len => argumentCount
    argumentCount > UIntSize(1) -> if {
        "captured child" -> println
    } else {
        "artifacts/example-tests/306-structured-process-output.txt" => outputPath
        [arguments[0], "--child", ~] => childArgv!
        process.RunToFileRequest { argv: childArgv!, output: outputPath } -> process.runToFile => childResult
        childResult -> when {
            Ok(exitCode) {
                outputPath -> file.mapText => output!
                output! -> len => outputLength
                "capture = " -> print
                "$(exitCode)" -> print
                "," -> print
                "$(outputLength)" -> print
                "," -> print
                outputLength > UIntSize(0) -> if {
                    "$(output! -> byte(UIntSize(0)))" -> print
                } else {
                    "empty" -> print
                }
                "" -> println
            }
            Err(error) {
                error -> print
                "" -> println
            }
        }
    }
}
