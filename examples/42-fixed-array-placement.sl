main {
    [7; 8] => small
    small[7] => smallLast

    [9; 600] => large
    large[599] => largeLast

    "small = $smallLast" -> println
    "large = $largeLast" -> println
}
