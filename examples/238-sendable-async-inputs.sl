struct Point {
    x: Int
    y: Int
}

struct Packet {
    label: Text
    values: [Int; ~]
}

enum Message {
    Empty
    Number(box Int)
}

echoText value: Text -> async Text {
    value
}

double value: Double -> async Double {
    value * Double(2.0)
}

total point: Point -> async Int {
    point.x + point.y
}

roundTrip packet: move Packet -> async Packet {
    packet
}

roundArray values: move [Int; ~] -> async [Int; ~] {
    values
}

roundBox value: move box Int -> async box Int {
    value
}

roundMessage value: move Message -> async Message {
    value
}

consume packet: move Packet -> async Int {
    packet.values -> len
}

dropBox value: move box Int -> Int {
    9
}

inspect message: Message -> Int {
    message -> when {
        Message.Empty => 0
        Message.Number(value) => 1
    }
}

main {
    "worker text" -> echoText => textTask
    Double(1.25) -> double => doubleTask
    Point { x: 20, y: 22 } -> total => pointTask

    [2, 3, 5, ~] => packetValues!
    Packet { label: "packet", values: packetValues! } => packet!
    packet! -> roundTrip => packetTask

    [7, 11, 13, ~] => values!
    values! -> roundArray => arrayTask

    box 9 => boxed!
    boxed! -> roundBox => boxTask

    Message.Number(box 17) => message!
    message! -> roundMessage => messageTask

    [19, 23, ~] => ignoredValues!
    Packet { label: "ignored", values: ignoredValues! } => ignoredPacket!
    ignoredPacket! -> consume => ignoredTask

    textTask -> await => text
    doubleTask -> await => measured
    pointTask -> await => sum
    packetTask -> await => returnedPacket!
    arrayTask -> await => returnedValues!
    boxTask -> await => returnedBox!
    messageTask -> await => returnedMessage!

    text -> println
    measured > Double(2.4) -> if { "double-ok=true,point=$sum" -> println } else { "double-ok=false,point=$sum" -> println }
    "$(returnedPacket!.label)=$(returnedPacket!.values -> len)" -> println
    "array=$(returnedValues! -> len)" -> println
    returnedBox! -> dropBox => boxValue
    returnedMessage! -> inspect => messageValue
    "box=$boxValue,message=$messageValue" -> println
}
