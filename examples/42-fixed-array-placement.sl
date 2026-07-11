main {
    [7; 8] => small
    small[7] => smallLast

    [9; 1200] => large
    large[1199] => largeLast

    "small = $smallLast" -> println
    "large = $largeLast" -> println
}
