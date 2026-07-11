struct NumericLayout {
    tiny: Int8
    short: Int16
    word: Int32
    wide: Int64
    byte: UInt8
    real32: Float32
    real64: Float64
}

addSmall value: Int8 -> Int8 => value + Int8(2)
addUnsigned value: UInt16 -> UInt16 => value + UInt16(5)
scale value: Float32 -> Float32 => value * Float32(2.0)
precise value: Double -> Double => value / Double(2.0)
narrow value: Int -> Int8 => Int8(value)

main {
    Int8(40) -> addSmall => small
    UInt16(37) -> addUnsigned => unsigned
    UInt64(18446744073709551615) => maxUnsigned
    Float32(1.5) -> scale => single
    Double(9.0) -> precise => double
    120 -> narrow => narrowed
    NumericLayout {
        tiny: small,
        short: Int16(32000),
        word: Int32(2000000000),
        wide: Long(42),
        byte: UInt8(255),
        real32: single,
        real64: double
    } => layout

    "signed = $(layout.tiny), $(layout.short), $(layout.word), $(layout.wide), $narrowed" -> println
    "unsigned = $unsigned, $(layout.byte), $maxUnsigned" -> println
    "float as int = $(Int(single)), $(Int(double))" -> println
    [Int16(7), Int16(8)] -> each item {
        "fixed integer item = $item" -> println
    }
    [UInt8; ~] => bytes!
    bytes! -> push(UInt8(65))
    bytes! -> push(UInt8(90))
    "bytes = $(bytes![0]), $(bytes![1])" -> println
}
