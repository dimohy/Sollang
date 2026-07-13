import smalllang.compiler.llvm.target as target

main {
    target.windowsX64 => windows
    target.linuxX64 => linux
    target.wasm32Browser => wasm
    "windows = $(windows.pointerBitWidth),$(windows.objectFormat)" -> println
    windows.dataLayoutLine -> println
    windows.tripleLine -> println
    "linux = $(linux.pointerBitWidth),$(linux.objectFormat)" -> println
    linux.dataLayoutLine -> println
    linux.tripleLine -> println
    "wasm = $(wasm.pointerBitWidth),$(wasm.objectFormat)" -> println
    wasm.dataLayoutLine -> println
    wasm.tripleLine -> println
}
