import smalllang.compiler.llvm.target as target

main {
    target.windowsX64 => windows
    "target = $(windows.pointerBitWidth),$(windows.objectFormat)" -> println
    windows.dataLayoutLine -> println
    windows.tripleLine -> println
}
