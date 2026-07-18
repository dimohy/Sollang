struct OwnedItem {
    payload: box Int
}

main {
    [OwnedItem { payload: box 1 }, ~] => values
    values -> each item {
        item => copied
    }
}
