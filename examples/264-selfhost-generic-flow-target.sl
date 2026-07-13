import smalllang.compiler.semantic.calls as calls

main {
    """
    struct File {
        token: UInt64
    }

    readAt<T> file: File -> Int {
        1
    }

    main {
        File { token: UInt64(0) } => reader
        reader -> readAt<UInt16>(0) => value
    }
    """ => source

    source -> calls.resolve => resolved!
    ((resolved! -> len) == 2 and resolved![1].status == 0) -> if {
        "generic flow calls=1"
    } else {
        "generic flow calls=failed"
    } -> println
}
