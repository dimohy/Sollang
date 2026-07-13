main {
    0 => outer!
    outer! < 2 -> while {
        outer! + 1 => outer!
        0 => inner!
        inner! < 4 -> while {
            inner! + 1 => inner!
            box inner! => owned
            inner! == 2 -> if continue
            inner! == 3 -> if break
            "body=$(inner!)" -> println
        }
        "outer=$(outer!)" -> println
    }
    "done" -> println
}
