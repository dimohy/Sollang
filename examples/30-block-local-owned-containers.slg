main {
    1..3 -> each i {
        [Int; 2~] => row!
        row! -> push(i)
        row! -> push(i * 10)

        row! -> fold 0 sum, value {
            sum + value
        } => rowTotal

        "row $i = $rowTotal" -> println
    }

    true -> if {
        [Int; 2~] => values!
        values! -> push(10)
        values!
    } else {
        [Int; 2~] => values!
        values! -> push(20)
        values!
    } => selected!

    selected! -> push(30)
    selected! -> fold 0 sum, value {
        sum + value
    } => selectedTotal

    "selected = $selectedTotal" -> println
}
