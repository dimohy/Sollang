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
    """
    target triple = "x86_64-pc-windows-msvc"
    """ => tripleLine
    """
    target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
    """ => dataLayoutLine
    TargetDescriptor {
        tripleLine: tripleLine
        dataLayoutLine: dataLayoutLine
        pointerBitWidth: 64
        objectFormat: 1
    }
}

public linuxX64: -> TargetDescriptor {
    """
    target triple = "x86_64-unknown-linux-gnu"
    """ => tripleLine
    """
    target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
    """ => dataLayoutLine
    TargetDescriptor {
        tripleLine: tripleLine
        dataLayoutLine: dataLayoutLine
        pointerBitWidth: 64
        objectFormat: 2
    }
}

public wasm32Browser: -> TargetDescriptor {
    """
    target triple = "wasm32-unknown-unknown-wasm"
    """ => tripleLine
    """
    target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20"
    """ => dataLayoutLine
    TargetDescriptor {
        tripleLine: tripleLine
        dataLayoutLine: dataLayoutLine
        pointerBitWidth: 32
        objectFormat: 3
    }
}
