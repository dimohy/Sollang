namespace sys.runtime

public print value: Text -> Unit = intrinsic

public println value: Text -> Unit = intrinsic

public readInt prompt: Text -> Int = intrinsic

public seedRandom value: Int -> Unit = intrinsic

public randomBelow maxExclusive: Int -> Int = intrinsic

public openIntWriter path: Text -> Unit = intrinsic

public writeInt value: Int -> Unit = intrinsic

public closeIntWriter: -> Unit = intrinsic

public openIntReader path: Text -> Unit = intrinsic

public closestInt target: Int -> Int = intrinsic

public closeIntReader: -> Unit = intrinsic

public nowMillis: -> Long = intrinsic

public parallel<T, R> values: [T; ~] -> [R; ~] block item: T -> R = intrinsic

public parallelWorkers: -> Int = intrinsic

public parallelPeakWorkers: -> Int = intrinsic
