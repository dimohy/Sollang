import smalllang.compiler.semantic.context as semantic

main {
    [
        """
        namespace sample.library

        public double value: Int -> Int {
            value * 2
        }
        """,
        """
        namespace sample.main

        import sample.library as library

        main {
            21 -> library.double
        }
        """,
        ~
    ] => sources!
    sources! -> semantic.prepare => snapshot
    "$(snapshot.package.ranges -> len)/$(snapshot.modules -> len)/$(snapshot.imports -> len)/$(snapshot.resolvedImports -> len)" -> println
}
