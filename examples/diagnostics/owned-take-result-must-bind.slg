struct OwnedValues {
    values: [Int; ~]
}

main {
    [OwnedValues; { values: [1, ~] }, ~] => values!
    values! -> take(0)
}
