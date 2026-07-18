struct Package {
    labels: [Text; ~]
    id: Int
}

firstLabel package: move Package -> Text {
    package.id => id
    package.labels => labels!
    labels![0]
}

main {
    Package {
        labels: ["lexer", "parser", ~]
        id: 7
    } => package!
    firstLabel(package!) => label
    label -> println
}
