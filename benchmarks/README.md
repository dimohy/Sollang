# Sollang Benchmarks

## Container Throughput

`containers-throughput.slg` measures the current array and dictionary container
paths with the zero-input runtime timer exposed as `nowMillis`.

The checked-in numeric report is a dated machine-local snapshot, not a claim
about the latest compiler. Since that run, dictionary lowering gained 87.5%
load-factor growth, tombstones, H2 control bytes, wrapped eight-slot group
scans, direct candidate selection, and generic local/imported `Hash`/`Eq` key
dispatch. Re-run the commands below before making current performance claims.

Run:

```powershell
.\scripts\sollang.ps1 -Source benchmarks\containers-throughput.slg -Output artifacts\benchmarks\containers-throughput.exe -KeepTemps
.\artifacts\benchmarks\containers-throughput.exe
```

Run the C# comparison baseline:

```powershell
dotnet build benchmarks\csharp\ContainersThroughput\ContainersThroughput.csproj -c Release --nologo
dotnet run --project benchmarks\csharp\ContainersThroughput\ContainersThroughput.csproj -c Release --no-build
```

Run the Go comparison baseline:

```powershell
Push-Location benchmarks\go\containers-throughput
& 'C:\Program Files\Go\bin\go.exe' build -o ..\..\..\artifacts\benchmarks\go-containers-throughput.exe .
Pop-Location
.\artifacts\benchmarks\go-containers-throughput.exe
```

Run the Rust comparison baseline:

```powershell
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release --manifest-path benchmarks\rust\containers-throughput\Cargo.toml
.\benchmarks\rust\containers-throughput\target\release\containers-throughput.exe std
.\benchmarks\rust\containers-throughput\target\release\containers-throughput.exe hashbrown
```

Reported fields:

- `*Millis`: elapsed wall-clock milliseconds for the measured section.
- `*OpsPerSecond`: integer items-per-second throughput.
- `*Length` and `*Capacity`: final container size and backing capacity.
- `*BackingBytes`: estimated backing storage bytes for the container payload.
- `*AllocatedBytes`: C# managed allocation bytes for the measured section.
- `*Checksum`: correctness guard so the measured work cannot be removed later.

The benchmark follows common public benchmark metrics: elapsed time, input/iteration count, items-per-second throughput, and memory size. Exact allocation counters should be added when the Sollang runtime exposes allocator statistics.

`containers-smoke.slg` is a smaller correctness check for `nowMillis`, mutable
array push, dictionary put, fold, and lookup.
