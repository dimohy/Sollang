struct Bundle {
    label: Text
    values: [Int; ~]
}

enum Chain {
    End
    More(box Chain)
}

truth: -> async Bool {
    true
}

ratio: -> async Double {
    Double(3.5)
}

greeting: -> async Text {
    "hello"
}

numbers: -> async [Int; ~] {
    [2, 3, 5, 7, ~]
}

words: -> async {Int: Text} {
    { 1: "one", 2: "two" }
}

noop: -> async Unit {
    1 => completed
}

discarded: -> async [Int; ~] {
    [11, 13, ~]
}

bundle: -> async Bundle {
    [17, 19, 23, ~] => values!
    Bundle { label: "more primes", values: values! } => result!
    result!
}

boxedNumber: -> async box Int {
    box 29
}

chain: -> async Chain {
    Chain.More(box Chain.End)
}

consumeBox value: move box Int -> Int {
    29
}

inspectChain value: Chain -> Int {
    value -> when {
        Chain.End => 0
        Chain.More(tail) => 1
    }
}

main {
    truth => truthTask
    ratio => ratioTask
    greeting => greetingTask
    numbers => numbersTask
    words => wordsTask
    noop => unitTask
    discarded => ignoredTask
    bundle => bundleTask
    bundle => ignoredBundleTask
    boxedNumber => boxTask
    boxedNumber => ignoredBoxTask
    chain => chainTask
    chain => ignoredChainTask

    truthTask -> await => answer
    ratioTask -> await => measuredRatio
    greetingTask -> await => message
    numbersTask -> await => values!
    wordsTask -> await => words!
    unitTask -> await
    bundleTask -> await => result!
    boxTask -> await => boxed!
    chainTask -> await => chainResult!
    boxed! -> consumeBox => boxValue
    chainResult! -> inspectChain => chainDepth

    answer -> if { "answer=true" -> println } else { "answer=false" -> println }
    message -> println
    "values=$(values! -> len),last=$(values![3])" -> println
    words![2] -> println
    "$(result!.label)=$(result!.values -> len)" -> println
    "box=$boxValue" -> println
    "chain=$chainDepth" -> println
    measuredRatio > Double(3.0) -> if { "ratio-ok=true" -> println } else { "ratio-ok=false" -> println }
}
