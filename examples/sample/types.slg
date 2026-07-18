namespace sample.types

public struct Counter {
    value: Int
}

public enum Status {
    Ready
    Failed(Int)
}

public trait Readable {
    read: self -> Int
}

impl Readable for Counter {
    public read: self -> Int {
        self.value
    }
}
