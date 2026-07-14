import smalllang.compiler.semantic.type_check as typeCheck

main {
    [
        """
        transform value: Int -> Int block item: Int {
            value -> yield
            value
        }

        plain value: Int -> Int => value

        main {
            true -> transform item { item }
            1 -> plain item { item }
        }
        """,
        ~
    ] => sources!
    sources! -> typeCheck.analyze => errors!
    false => sourceMismatch!
    false => nonBlockTarget!
    errors! -> each error {
        error.code == 6 -> if {
            true => sourceMismatch!
        }
        error.code == 17 -> if { true => nonBlockTarget! }
    }
    ((errors! -> len) == 2 and sourceMismatch! and nonBlockTarget!) -> if {
        "role block contract = valid"
    } else {
        "role block contract = invalid"
    } -> println
}
