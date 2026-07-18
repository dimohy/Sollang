struct Point {
    x: Int
    y: Int
}

struct Owned {
    value: box Int
}

fixedLength<N: Int, T> values: [T; N] -> Int {
    values -> len
}

first<N: Int, T> values: [T; N] -> T {
    values[0]
}

main {
    [10, 20, 30] => threeValues
    [1, 2, 3, 4, 5] => fiveValues
    ["lexer", "parser", "llvm"] => stages
    [Point; { x: 10, y: 20 }, { x: 30, y: 40 }] => points
    [Owned; { value: box 10 }, { value: box 20 }] => owned
    threeValues -> fixedLength<3> => three
    fiveValues -> fixedLength<5> => five
    stages -> fixedLength<3> => stageCount
    points -> fixedLength<2> => pointCount
    owned -> fixedLength<2> => ownedCount
    stages -> first<3> => firstStage
    points -> first<2> => firstPoint
    "three = $three" -> println
    "five = $five" -> println
    "stages = $stageCount" -> println
    "points = $pointCount" -> println
    "owned = $ownedCount" -> println
    "first stage = $firstStage" -> println
    "first point x = $(firstPoint.x)" -> println
}
