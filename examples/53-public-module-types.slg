import sample.types as types

main {
    types.Counter { value: 42 } => counter
    counter.value => answer
    counter -> types.Readable.read => traitAnswer
    types.Status.Ready => status
    "public type = $answer" -> println
    "public trait = $traitAnswer" -> println
}
