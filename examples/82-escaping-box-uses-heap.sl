struct Pixel {
    x: Int
    y: Int
}

makePixel: -> box Pixel {
    box Pixel { x: 20, y: 22 }
}

sum pixel: move box Pixel -> Int {
    pixel.x + pixel.y
}

main {
    makePixel => pixel
    pixel -> sum => answer
    "heap pixel = $answer" -> println
}
