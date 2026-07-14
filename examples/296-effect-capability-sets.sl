announce text: Text -> Unit uses Console {
    text -> println
}

relay text: Text -> Unit uses Console {
    text -> announce
}

main {
    "effect sets" -> relay
}
