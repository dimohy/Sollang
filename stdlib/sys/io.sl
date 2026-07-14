namespace sys.io

import sys.runtime as rt

print value: Text -> Unit uses Console {
    value -> rt.print
}

println value: Text -> Unit uses Console {
    value -> rt.println
}

readInt prompt: Text -> Int uses Console {
    prompt -> rt.readInt
}
