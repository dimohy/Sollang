checkLargeMapInference: -> UIntSize {
    # Explicit UInt64(4_000_000_000) and UIntSize(64) remain valid too.
    map read "unused-large-file.bin" at 4_000_000_000 for 64 => unused
    unused -> len
}

main {
    map write "artifacts/example-tests/82-memory-mapped-bytes.bin" size 8 => data!
    data![0] = UInt8(65)
    data![1] = UInt8(66)
    data![2] = UInt8(67)
    data![3] = UInt8(68)

    data! -> len => length
    "mapped length = $length" -> println
    data! -> each byte {
        "mapped byte = $byte" -> println
    }
    data! -> flush
}
