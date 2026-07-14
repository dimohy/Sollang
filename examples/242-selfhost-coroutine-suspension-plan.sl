import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        child value: Int -> async Int {
            value + 1
        }

        parent value: Int -> async Int {
            value * 2 => base
            [1, 2, 3, ~] => values!
            value -> child => firstTask
            value -> child => secondTask
            firstTask -> await => first
            secondTask -> await => second
            base + first + second + (values! -> len)
        }

        main { }
        """,
        ~
    ] => sources!

    sources! -> typedIr.coroutinePlan => plan
    0 => taskSlots!
    0 => ownedSlots!
    0 => slotIndex!
    slotIndex! < (plan.slots -> len) -> while {
        ((plan.slots[slotIndex!].flags / 4) % 2 == 1) -> if { taskSlots! + 1 => taskSlots! }
        ((plan.slots[slotIndex!].flags / 2) % 2 == 1) -> if { ownedSlots! + 1 => ownedSlots! }
        slotIndex! + 1 => slotIndex!
    }
    "suspensions=$(plan.points -> len),states=$(plan.points[0].state)/$(plan.points[1].state),slots=$(plan.slots -> len),taskSlots=$(taskSlots!),ownedSlots=$(ownedSlots!),destroySlots=$(plan.destroys -> len)" -> println
}
