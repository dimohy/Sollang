step value: Int -> async Int {
    value + 1
}

choose value: Int -> async Int {
    value * 10 => saved
    value > 0 -> if {
        box value => owned
        value -> step => pending
        pending -> await => next
        saved + next
    } else {
        box value => owned
        0 -> step => pending
        pending -> await => next
        saved - next
    }
}

classify value: Int -> async Int {
    value + 100 => saved
    when {
        value < 0 {
            0 -> step => pending
            pending -> await => next
            saved - next
        }
        value == 0 {
            1 -> step => pending
            pending -> await => next
            saved + next
        }
        else {
            value -> step => pending
            pending -> await => next
            saved + next
        }
    }
}

accumulate value: Int -> async Int {
    value => total!
    value > 0 -> if {
        value -> step => pending
        pending -> await => next
        total! + next => total!
    } else {
        total! - 1 => total!
    }
    total!
}

grow value: Int -> async Int {
    [value, ~] => values!
    value > 0 -> if {
        value -> step => pending
        pending -> await => next
        values! -> push(next)
    } else {
        values! -> push(0)
    }
    values! -> len
}

main {
    3 -> choose => positive
    -2 -> choose => negative
    0 -> classify => zero
    4 -> classify => other
    3 -> accumulate => accumulated
    -2 -> accumulate => untouched
    5 -> grow => grown
    -1 -> grow => fallbackGrowth
    8 -> choose => cancelled
    1 -> step => gate
    gate -> await => ignored
    cancelled -> cancel
    positive -> await => positiveValue
    negative -> await => negativeValue
    zero -> await => zeroValue
    other -> await => otherValue
    accumulated -> await => accumulatedValue
    untouched -> await => untouchedValue
    grown -> await => grownValue
    fallbackGrowth -> await => fallbackGrowthValue
    "if=$positiveValue/$negativeValue,when=$zeroValue/$otherValue,mutable=$accumulatedValue/$untouchedValue,owner=$grownValue/$fallbackGrowthValue" -> println
}
