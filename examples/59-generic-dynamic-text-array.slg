main {
    [Text; 2~] => stages!
    stages! -> push("lexer")
    stages! -> push("parser")
    stages! -> push("semantic")
    stages! -> push("llvm")
    stages![2] => third
    stages! -> len => count
    stages! -> capacity => capacity
    "dynamic stage = $third" -> println
    "dynamic count = $count" -> println
    "dynamic capacity = $capacity" -> println
}
