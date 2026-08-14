use std::env;

const MOD: i64 = 1_000_000_007;

fn gcd_value(mut a: i64, mut b: i64) -> i64 {
    while b != 0 { let next = a % b; a = b; b = next; }
    a
}

fn run_kernel(family: i32, n: i64, seed: i64) -> i64 {
    let mut acc = seed;
    match family {
        1 => for i in 1..=n { acc = (acc + i) % MOD; },
        2 => for i in 1..=n { let x = i % 10_000; acc = (acc + x * x) % MOD; },
        3 => { let mut x = seed; for _ in 0..n { x = (x * 482 + 1) % 1_000_003; acc = (acc + x) % MOD; } },
        4 => for i in 1..=n { if (i + seed) % 7 < 3 { acc += i % 1009; } else { acc += MOD - i % 997; } acc %= MOD; },
        5 => for i in 1..=n { acc = (acc + gcd_value(i * 17 + seed, i * 13 + 97)) % MOD; },
        6 => { acc = 0; for i in 1..=n { let mut x = (i + seed) % 100_000 + 1; while x != 1 { x = if x % 2 == 0 { x / 2 } else { x * 3 + 1 }; acc += 1; } } acc %= MOD; },
        7 => { acc = 0; for x in 2..=n { let mut prime = true; let mut d = 2; while d <= x / d && prime { if x % d == 0 { prime = false; } d += 1; } if prime { acc += 1; } } },
        8 => { acc = 0; for x in 1..=n { let mut d = 1; while d <= x / d { if x % d == 0 { acc += d; if d != x / d { acc += x / d; } acc %= MOD; } d += 1; } } },
        9 => { acc = 0; for i in 0..n { let (mut a, mut b) = (seed, seed + 1); for _ in 0..24 { let next = (a + b) % MOD; a = b; b = next; } acc = (acc + b + i % 17) % MOD; } },
        10 => { acc = 0; for i in 0..n { let x = (i + seed) % 1009; let mut p = 17; for c in 1..=12 { p = (p * x + c * 13) % 1_000_003; } acc = (acc + p) % MOD; } },
        11 => for i in 1..=n { for j in 1..=i { acc = (acc + (i + j) % 97) % MOD; } },
        12 => { let (mut x, mut low, mut high) = (seed, MOD, 0); for _ in 0..n { x = (x * 482 + 1) % 1_000_003; if x < low { low = x; } if x > high { high = x; } } acc = (low + high) % MOD; },
        13..=16 => {
            let mut values: Vec<i64> = (0..n).map(|i| ((i % 1009) * 37 + seed) % 1009).collect();
            acc = 0;
            if family == 13 { for &value in &values { acc = (acc + value) % MOD; } }
            if family == 14 { for &value in values.iter().rev() { acc = (acc + value) % MOD; } }
            if family == 15 { for pass in 0..16 { let mut i = pass; while i < n { acc = (acc + values[i as usize]) % MOD; i += 16; } } }
            if family == 16 { for i in 1..values.len() { values[i] = (values[i] + values[i - 1]) % MOD; } acc = values[values.len() - 1]; }
        },
        17 => {
            let mut x = seed;
            let mut values = Vec::with_capacity(n as usize);
            for _ in 0..n { x = (x * 482 + 1) % 1_000_003; values.push(x); }
            for i in 1..values.len() { let value = values[i]; let mut j = i; while j > 0 && values[j - 1] > value { values[j] = values[j - 1]; j -= 1; } values[j] = value; }
            acc = (values[0] + values[values.len() / 2] + values[values.len() - 1]) % MOD;
        },
        18 => {
            let mut limit = 0_i64;
            while limit + 1 <= n / (limit + 1) { limit += 1; }
            let mut base = vec![0_i64; limit as usize + 1];
            let mut p = 2_i64;
            while p <= limit / p { if base[p as usize] == 0 { let mut m = p * p; while m <= limit { base[m as usize] = 1; m += p; } } p += 1; }
            const SEGMENT_SIZE: i64 = 32768;
            let mut segment = vec![0_i64; SEGMENT_SIZE as usize];
            acc = 0;
            let mut low = 2_i64;
            while low <= n {
                let high = (low + SEGMENT_SIZE - 1).min(n);
                let active = high - low + 1;
                for i in 0..active { segment[i as usize] = 0; }
                for prime in 2..=limit { if base[prime as usize] == 0 { let mut start = ((low + prime - 1) / prime) * prime; if start < prime * prime { start = prime * prime; } let mut multiple = start; while multiple <= high { segment[(multiple - low) as usize] = 1; multiple += prime; } } }
                for i in 0..active { if segment[i as usize] == 0 { acc += 1; } }
                low = high + 1;
            }
        },
        19 => {
            let cells = (n * n) as usize;
            let a: Vec<i64> = (0..cells as i64).map(|i| (i * 17 + seed) % 101).collect();
            let b: Vec<i64> = (0..cells as i64).map(|i| (i * 31 + seed) % 103).collect();
            let mut c = vec![0_i64; cells];
            for row in 0..n as usize { for k in 0..n as usize { for col in 0..n as usize { c[row * n as usize + col] += a[row * n as usize + k] * b[k * n as usize + col]; } } }
            acc = c.into_iter().fold(0, |sum, value| (sum + value) % MOD);
        },
        20 => {
            let values: Vec<i64> = (0..n).map(|i| i * 2 + seed).collect();
            acc = 0;
            for q in 0..n { let target = (((q % 100_000) * 7919) % n) * 2 + seed; let (mut lo, mut hi) = (0_usize, values.len()); while lo < hi { let mid = lo + (hi - lo) / 2; if values[mid] < target { lo = mid + 1; } else { hi = mid; } } acc = (acc + lo as i64) % MOD; }
        },
        _ => std::process::exit(2),
    }
    acc
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 4 { std::process::exit(2); }
    let family = args[1].parse().unwrap();
    let n = args[2].parse().unwrap();
    let seed = args[3].parse().unwrap();
    println!("{}", run_kernel(family, n, seed));
}
