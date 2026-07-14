mappedLength: -> UIntSize {
    map read "data.bin" at 0 for 16 => data
    data -> len
}

main {
}
