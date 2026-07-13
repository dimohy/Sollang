struct Workspace {
    memory: Arena
}

invalid: -> async Workspace {
    Workspace { memory: Arena(8) }
}

main {
}
