import smalllang.compiler.parser as parser

main {
    """
    okValue result: Result<Int, Text> -> Int => result -> when {
        Ok(value) => value
        else => 0
    }

    errorValue result: Result<Int, Text> -> Int => result -> when {
        Err(error) => 0
        else => 1
    }

    noneValue option: Option<Int> -> Int => option -> when {
        None => 0
        else => 1
    }

    exhaustiveValue result: Result<Int, Text> -> Int => result -> when {
        Ok(value) => value
        Err(error) => 0
    }

    main {
    }
    """ => contextualSource
    contextualSource -> parser.parseEvents => events!

    events! -> len => eventCount
    events![eventCount - 1].value == 1 -> if {
        "contextual enum parser = valid" -> println
    } else {
        "contextual enum parser = invalid" -> println
    }
}
