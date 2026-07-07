getName: -> Text {
    "dimohy"
}

getNum: -> Int {
    20 + 22
}

main {
    name = getName()
    num = getNum()
    "Hello, {name}. getNum() = {num}" -> print
}
