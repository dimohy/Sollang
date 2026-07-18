primes: -> async [Int; ~] {
    [2, 3, 5, 7, 11, ~]
}

forwardPrimes: -> async [Int; ~] {
    primes => pending
    pending -> await
}

main {
    forwardPrimes => task
    task -> await => values!
    "count=$(values! -> len),last=$(values![4])" -> println
}
