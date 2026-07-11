struct OwnedError {
    payload: box Int
}

propagate: -> Result<Int, OwnedError> {
    Result<Int, OwnedError>.Err(OwnedError { payload: box 1 })? => value
    Result<Int, OwnedError>.Ok(value)
}

main {
    propagate => result
}
