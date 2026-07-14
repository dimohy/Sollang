import smalllang.compiler.parser as parser

main {
    """
    build seed: Int -> Int block field: Int {
        seed -> yield
        seed + 1
    }

    main {
        10 -> build field {
        } => built
    }
    """ => roleSource
    roleSource -> parser.parseEvents => events!

    events! -> len => eventCount
    events![eventCount - 1].value == 1 -> if {
        "role parser = valid" -> println
    } else {
        "role parser = invalid" -> println
    }
}
