work: -> async Unit {
    1 => finished
}

main {
    work => task
    task -> await
    task -> await
}
