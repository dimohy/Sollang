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

# Maps values concurrently and stops claiming new work after a callback returns
# Err. Already-started callbacks are joined before the deterministic earliest
# error or the ordered successful array is returned.
public tryParallel<T, R, E> values: [T; ~] -> Result<[R; ~], E> block item: T -> Result<R, E> = intrinsic

# Sets the bounded compute-pool size before its first use and returns the
# effective limit. Values below one become one; values above 64 become 64.
public limitParallelWorkers maxWorkers: Int -> Int = intrinsic

public parallelWorkers: -> Int = intrinsic

public parallelPeakWorkers: -> Int = intrinsic
