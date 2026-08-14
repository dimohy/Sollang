const long Mod = 1_000_000_007;

static long Gcd(long a, long b)
{
    while (b != 0) { var next = a % b; a = b; b = next; }
    return a;
}

static long RunKernel(int family, long n, long seed)
{
    long acc = seed;
    switch (family)
    {
        case 1:
            for (long i = 1; i <= n; i++) acc = (acc + i) % Mod;
            break;
        case 2:
            for (long i = 1; i <= n; i++) { var x = i % 10_000; acc = (acc + x * x) % Mod; }
            break;
        case 3:
            { long x = seed; for (long i = 0; i < n; i++) { x = (x * 482 + 1) % 1_000_003; acc = (acc + x) % Mod; } }
            break;
        case 4:
            for (long i = 1; i <= n; i++) { acc += (i + seed) % 7 < 3 ? i % 1009 : Mod - i % 997; acc %= Mod; }
            break;
        case 5:
            for (long i = 1; i <= n; i++) acc = (acc + Gcd(i * 17 + seed, i * 13 + 97)) % Mod;
            break;
        case 6:
            acc = 0;
            for (long i = 1; i <= n; i++) { var x = (i + seed) % 100_000 + 1; while (x != 1) { x = x % 2 == 0 ? x / 2 : x * 3 + 1; acc++; } }
            acc %= Mod;
            break;
        case 7:
            acc = 0;
            for (long x = 2; x <= n; x++) { var prime = true; for (long d = 2; d <= x / d && prime; d++) if (x % d == 0) prime = false; if (prime) acc++; }
            break;
        case 8:
            acc = 0;
            for (long x = 1; x <= n; x++) for (long d = 1; d <= x / d; d++) if (x % d == 0) { acc += d; if (d != x / d) acc += x / d; acc %= Mod; }
            break;
        case 9:
            acc = 0;
            for (long i = 0; i < n; i++) { long a = seed, b = seed + 1; for (var step = 0; step < 24; step++) (a, b) = (b, (a + b) % Mod); acc = (acc + b + i % 17) % Mod; }
            break;
        case 10:
            acc = 0;
            for (long i = 0; i < n; i++) { var x = (i + seed) % 1009; long p = 17; for (var c = 1; c <= 12; c++) p = (p * x + c * 13) % 1_000_003; acc = (acc + p) % Mod; }
            break;
        case 11:
            for (long i = 1; i <= n; i++) for (long j = 1; j <= i; j++) acc = (acc + (i + j) % 97) % Mod;
            break;
        case 12:
            { long x = seed, low = Mod, high = 0; for (long i = 0; i < n; i++) { x = (x * 482 + 1) % 1_000_003; if (x < low) low = x; if (x > high) high = x; } acc = (low + high) % Mod; }
            break;
        case >= 13 and <= 16:
            {
                var values = new long[checked((int)n)];
                for (long i = 0; i < n; i++) values[i] = ((i % 1009) * 37 + seed) % 1009;
                acc = 0;
                if (family == 13) for (long i = 0; i < n; i++) acc = (acc + values[i]) % Mod;
                if (family == 14) for (long i = n; i > 0; i--) acc = (acc + values[i - 1]) % Mod;
                if (family == 15) for (long pass = 0; pass < 16; pass++) for (long i = pass; i < n; i += 16) acc = (acc + values[i]) % Mod;
                if (family == 16) { for (long i = 1; i < n; i++) values[i] = (values[i] + values[i - 1]) % Mod; acc = values[n - 1]; }
            }
            break;
        case 17:
            {
                var values = new long[checked((int)n)]; long x = seed;
                for (long i = 0; i < n; i++) { x = (x * 482 + 1) % 1_000_003; values[i] = x; }
                for (long i = 1; i < n; i++) { var value = values[i]; var j = i; while (j > 0 && values[j - 1] > value) { values[j] = values[j - 1]; j--; } values[j] = value; }
                acc = (values[0] + values[n / 2] + values[n - 1]) % Mod;
            }
            break;
        case 18:
            {
                long limit = 0; while (limit + 1 <= n / (limit + 1)) limit++;
                var baseComposite = new long[checked((int)limit + 1)];
                for (long p = 2; p <= limit / p; p++) if (baseComposite[p] == 0) for (long m = p * p; m <= limit; m += p) baseComposite[m] = 1;
                const long segmentSize = 32768; var segment = new long[segmentSize]; acc = 0;
                for (long low = 2; low <= n;)
                {
                    var high = Math.Min(low + segmentSize - 1, n); var active = high - low + 1;
                    for (long i = 0; i < active; i++) segment[i] = 0;
                    for (long p = 2; p <= limit; p++) if (baseComposite[p] == 0)
                    {
                        var start = ((low + p - 1) / p) * p; if (start < p * p) start = p * p;
                        for (long m = start; m <= high; m += p) segment[m - low] = 1;
                    }
                    for (long i = 0; i < active; i++) if (segment[i] == 0) acc++;
                    low = high + 1;
                }
            }
            break;
        case 19:
            {
                var cells = checked((int)(n * n)); var a = new long[cells]; var b = new long[cells]; var c = new long[cells];
                for (long i = 0; i < cells; i++) { a[i] = (i * 17 + seed) % 101; b[i] = (i * 31 + seed) % 103; }
                for (long row = 0; row < n; row++) for (long k = 0; k < n; k++) for (long col = 0; col < n; col++) c[row * n + col] += a[row * n + k] * b[k * n + col];
                acc = 0; for (long i = 0; i < cells; i++) acc = (acc + c[i]) % Mod;
            }
            break;
        case 20:
            {
                var values = new long[checked((int)n)]; for (long i = 0; i < n; i++) values[i] = i * 2 + seed; acc = 0;
                for (long q = 0; q < n; q++) { var target = (((q % 100_000) * 7919) % n) * 2 + seed; long lo = 0, hi = n; while (lo < hi) { var mid = lo + (hi - lo) / 2; if (values[mid] < target) lo = mid + 1; else hi = mid; } acc = (acc + lo) % Mod; }
            }
            break;
        default: Environment.Exit(2); break;
    }
    return acc;
}

if (args.Length != 3) return 2;
Console.WriteLine(RunKernel(int.Parse(args[0]), long.Parse(args[1]), long.Parse(args[2])));
return 0;
