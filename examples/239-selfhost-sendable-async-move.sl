import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        struct Packet {
            value: box Int
        }

        roundTrip packet: move Packet -> async Packet {
            packet
        }

        main {
            Packet { value: box 7 } => packet
            packet -> roundTrip => pending
        }
        """,
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    ir! -> typedIr.movesFrom => moves!

    ir! -> each node {
        (node.kind == 6 and (node.flags / 8) % 2 == 1) -> if {
            "async move call flags=$(node.flags)" -> println
        }
    }
    "async move events=$(moves! -> len)" -> println
}
