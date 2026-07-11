struct OwnedEntry {
    payload: box Int
}

main {
    # Explicit form: { 1: OwnedEntry { payload: box 10 }, 2: OwnedEntry { payload: box 20 } }
    {Int: OwnedEntry; 1: { payload: box 10 }, 2: { payload: box 20 }} => entries
    entries -> len => count
    "owned dictionary count = $count" -> println
}
