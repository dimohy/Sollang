work: -> async Int {
    7
}

invalid: -> Int {
    work => task
    task -> await
}

main {
}
