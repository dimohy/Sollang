struct Inner {
    values: [Int; ~]
}

struct Outer {
    inner: Inner
    tail: [Int; ~]
}

main {
    Outer {
        inner: Inner { values: [1, 2, ~] }
        tail: [3, 4, ~]
    } => outer!

    [5, 6, 7, ~] => replacementValues!
    Inner { values: replacementValues! } => replacement!
    replacement! => outer!.inner

    [8, 9, 10, 11, ~] => outer!.tail

    "inner=$(outer!.inner.values -> len),tail=$(outer!.tail -> len)" -> println
}
