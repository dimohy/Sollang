import smalllang.compiler.llvm.text as llvm
import sys.process as process

isJobsOption value: Text -> Bool {
    (value -> len) == UIntSize(6) => matches!
    matches! -> if {
        ((value -> byte(UIntSize(0))) == UInt8(45) and (value -> byte(UIntSize(1))) == UInt8(45) and (value -> byte(UIntSize(2))) == UInt8(106) and (value -> byte(UIntSize(3))) == UInt8(111) and (value -> byte(UIntSize(4))) == UInt8(98) and (value -> byte(UIntSize(5))) == UInt8(115)) => matches!
    }
    matches!
}

parsePositiveInt value: Text -> Int {
    0 => parsed!
    (value -> len) > UIntSize(0) => valid!
    UIntSize(0) => index!
    (valid! and index! < (value -> len)) -> while {
        value -> byte(index!) => digit
        (digit < UInt8(48) or digit > UInt8(57)) -> if {
            false => valid!
        } else {
            parsed! * 10 + Int(digit - UInt8(48)) => parsed!
        }
        index! + UIntSize(1) => index!
    }
    (valid! and parsed! > 0) -> if { parsed! } else { -1 }
}

configureWorkerLimit optionStart: UIntSize -> Int uses Process {
    process.arguments => arguments
    0 => workers!
    optionStart < (arguments -> len) -> if {
        arguments[optionStart] -> isJobsOption -> if {
            optionStart + UIntSize(1) < (arguments -> len) -> if {
                arguments[optionStart + UIntSize(1)] -> parsePositiveInt => requested
                requested > 0 -> if {
                    requested -> limitParallelWorkers => workers!
                } else { -1 => workers! }
            } else { -1 => workers! }
        }
    }
    workers!
}

sourceStart optionStart: UIntSize -> UIntSize uses Process {
    process.arguments => arguments
    optionStart => start!
    optionStart < (arguments -> len) -> if {
        arguments[optionStart] -> isJobsOption -> if { optionStart + UIntSize(2) => start! }
    }
    start!
}

collectPaths start: UIntSize -> [Text; ~] uses Process {
    process.arguments => arguments
    arguments -> len => argumentCount
    [Text; ~] => paths!
    start => index!
    index! < argumentCount -> while {
        arguments[index!] => path
        paths! -> push(path)
        index! + UIntSize(1) => index!
    }
    paths!
}

collectBuildPaths start: UIntSize -> [Text; ~] uses Process {
    process.arguments => arguments
    arguments -> len => argumentCount
    [Text; ~] => paths!
    start => index!
    index! < argumentCount -> while {
        arguments[index!] => path
        paths! -> push(path)
        index! + UIntSize(1) => index!
    }
    paths!
}

emitLinuxFiles pathStart: UIntSize -> Unit uses Console, File, Process {
    pathStart -> collectPaths => paths!
    paths! -> llvm.emitLinuxFiles
}

emitWasmFiles pathStart: UIntSize -> Unit uses Console, File, Process {
    pathStart -> collectPaths => paths!
    paths! -> llvm.emitWasmFiles
}

emitWindowsFiles pathStart: UIntSize -> Unit uses Console, File, Process {
    pathStart -> collectPaths => paths!
    paths! -> llvm.emitFiles
}

buildWindows pathStart: UIntSize -> Unit uses Console, File, Process {
    process.arguments => arguments
    pathStart -> collectBuildPaths => sourcePaths!
    [arguments[0], "windows", ~] => emitArgv!
    pathStart > UIntSize(5) -> if {
        emitArgv! -> push(arguments[5])
        emitArgv! -> push(arguments[6])
    }
    sourcePaths! -> each sourcePath { emitArgv! -> push(sourcePath) }
    process.RunToFileRequest {
        argv: emitArgv!
        output: arguments[2]
    } -> process.runToFile => emitted

    emitted -> when {
        Ok(emitCode) {
            emitCode == 0 -> if {
                [arguments[4], arguments[2], "-O1", "-Wno-override-module", "-o", arguments[3], ~] => clangArgv!
                clangArgv! -> process.run => compiled
                compiled -> when {
                    Ok(clangCode) => "native build = $(clangCode)" -> println
                    Err(error) => "native compiler invocation failed" -> println
                }
            } else {
                "emit failed" -> println
            }
        }
        Err(error) => "compiler emission failed" -> println
    }
}

main {
    process.arguments => arguments
    arguments[1] -> len => targetLength
    UIntSize(2) => optionStart!
    targetLength == UIntSize(13) -> if { UIntSize(5) => optionStart! }
    optionStart! -> configureWorkerLimit => workers
    optionStart! -> sourceStart => pathStart
    workers < 0 -> if {
        "; smalllang error: --jobs expects a positive integer" -> println
    } else {
    workers > 0 -> if { "; smalllang workers = $workers" -> println }
    targetLength == UIntSize(13) -> if {
        pathStart -> buildWindows
    } else {
    targetLength == UIntSize(5) -> if {
        pathStart -> emitLinuxFiles
    } else {
        targetLength == UIntSize(4) -> if {
            pathStart -> emitWasmFiles
        } else {
            pathStart -> emitWindowsFiles
        }
    }
    }
    }
}
