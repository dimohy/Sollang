import smalllang.compiler.llvm.text as llvm
import sys.process as process

collectPaths: -> [Text; ~] uses Process {
    process.arguments => arguments
    arguments -> len => argumentCount
    [Text; ~] => paths!
    UIntSize(2) => index!
    index! < argumentCount -> while {
        arguments[index!] => path
        paths! -> push(path)
        index! + UIntSize(1) => index!
    }
    paths!
}

emitLinuxFiles: -> Unit uses Console, File, Process {
    collectPaths => paths!
    paths! -> llvm.emitLinuxFiles
}

emitWasmFiles: -> Unit uses Console, File, Process {
    collectPaths => paths!
    paths! -> llvm.emitWasmFiles
}

emitWindowsFiles: -> Unit uses Console, File, Process {
    collectPaths => paths!
    paths! -> llvm.emitFiles
}

main {
    process.arguments => arguments
    arguments[1] -> len => targetLength
    targetLength == UIntSize(5) -> if {
        emitLinuxFiles
    } else {
        targetLength == UIntSize(4) -> if {
            emitWasmFiles
        } else {
            emitWindowsFiles
        }
    }
}
