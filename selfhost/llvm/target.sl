namespace smalllang.compiler.llvm.target

# Stable target metadata consumed by the self-hosted LLVM text backend. Object
# format: 1 COFF, 2 ELF, 3 WebAssembly.
public struct TargetDescriptor {
    tripleLine: Text
    dataLayoutLine: Text
    pointerBitWidth: Int
    objectFormat: Int
}

public windowsX64: -> TargetDescriptor {
    """"
    target triple = "x86_64-pc-windows-msvc"
    """" => tripleLine
    """"
    target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
    """" => dataLayoutLine
    TargetDescriptor {
        tripleLine: tripleLine
        dataLayoutLine: dataLayoutLine
        pointerBitWidth: 64
        objectFormat: 1
    }
}
