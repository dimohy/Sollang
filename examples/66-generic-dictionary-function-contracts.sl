lookupStage stages: {Text: Int} -> Int {
    stages["parser"]
}

addStage stages: mut {Text: Int} -> Unit {
    stages -> put("llvm", 4)
}

forwardStages stages: move {Text: Int} -> {Text: Int} => stages

main {
    { "lexer": 1, "parser": 2 } => stages!
    stages! -> lookupStage => parser
    stages! -> addStage
    stages!["llvm"] => llvm
    stages! -> forwardStages => stages!
    stages! -> len => count
    "contract parser = $parser" -> println
    "contract llvm = $llvm" -> println
    "contract count = $count" -> println
}
