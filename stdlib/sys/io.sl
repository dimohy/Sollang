sys.io.print value: Text -> Unit {
    value -> sys.runtime.print
}

sys.io.println value: Text -> Unit {
    value -> sys.runtime.println
}

sys.io.readInt prompt: Text -> Int {
    prompt -> sys.runtime.readInt
}
