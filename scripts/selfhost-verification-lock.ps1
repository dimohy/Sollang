function Enter-SelfHostVerificationLock {
    $mutex = [System.Threading.Mutex]::new($false, "Local\Sollang.SelfHost.Verification")
    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
    }
    if (-not $acquired) {
        $mutex.Dispose()
        throw "another Sollang self-host Stage2/Stage3 verification already owns the shared artifacts"
    }
    return $mutex
}

function Release-SelfHostVerificationLock {
    param([System.Threading.Mutex]$Mutex)

    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
