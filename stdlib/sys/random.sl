namespace sys.random

import sys.runtime as rt

seed value: Int -> Unit uses Random {
    value -> rt.seedRandom
}

below maxExclusive: Int -> Int uses Random {
    maxExclusive -> rt.randomBelow
}
