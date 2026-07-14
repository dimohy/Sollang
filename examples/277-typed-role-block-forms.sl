build seed: Int -> Int uses Console block field: Int {
    "build:begin" -> println
    seed -> yield
    "build:end" -> println
    seed + 1
}

with resource: Int -> Int uses Console block context: Int {
    "with:acquire" -> println
    resource -> yield
    "with:release" -> println
    resource * 2
}

handle operation: Int -> Int uses Console block effect: Int {
    "handle:install" -> println
    operation -> yield
    "handle:resolve" -> println
    operation + 100
}

main {
    10 -> build field {
        "build:field=$field" -> println
    } => product

    20 -> with context {
        "with:context=$context" -> println
    } => scoped

    30 -> handle effect {
        "handle:effect=$effect" -> println
    } => handled

    "results=$product,$scoped,$handled" -> println
}
