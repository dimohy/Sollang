struct Pixel {
    x: Int
    y: Int
}

main {
    box Pixel { x: 20, y: 22 } => pixel
    "stack pixel = $(pixel.x), $(pixel.y)" -> println
}
