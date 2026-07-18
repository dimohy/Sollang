struct OwnedValues {
    values: [Int; ~]
}

main {
    [OwnedValues;
        { values: [10, 11, ~] },
        { values: [20, 21, 22, ~] },
        ~
    ] => batches!
    batches! -> take(0) => first!
    first!.values -> len => firstLength
    batches! -> len => remainingBatches

    {Int: OwnedValues;
        1: { values: [30, ~] },
        2: { values: [40, 41, ~] }
    } => indexed!
    indexed! -> take(2) => selected!
    selected!.values -> len => selectedLength
    indexed! -> len => remainingEntries

    "taken lengths = $firstLength,$selectedLength; remaining = $remainingBatches,$remainingEntries" -> println
}
