struct OwnedValue {
    payload: box Int
}

main {
    { 1: OwnedValue { payload: box 10 } } => values
    values -> eachValue item {
        item => copied
    }
}
