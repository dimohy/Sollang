enum Chain {
    End
    More(box Chain)
}

inspect chain: Chain -> Int {
    chain -> when {
        Chain.End => 0
        Chain.More(tail) => 1
    }
}

main {
    Chain.More(box Chain.More(box Chain.End)) => chain
    chain -> inspect => first
    chain -> inspect => second
    "chain = $first, $second" -> println
}
