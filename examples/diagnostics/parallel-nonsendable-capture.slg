main {
    Arena(8) => memory
    [1, 2, 3, ~] => values!
    values! -> parallel value {
        value + Int(memory -> used)
    } => shifted!
}
