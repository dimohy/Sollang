use std::alloc::{GlobalAlloc, Layout, System};
use std::collections::HashSet;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Instant;

struct CountingAllocator;
static ALLOCS: AtomicU64 = AtomicU64::new(0);
static BYTES: AtomicU64 = AtomicU64::new(0);

unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        ALLOCS.fetch_add(1, Ordering::Relaxed);
        BYTES.fetch_add(layout.size() as u64, Ordering::Relaxed);
        unsafe { System.alloc(layout) }
    }
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) }
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

fn workload(count: i32) -> (i64, usize, usize) {
    let mut values = HashSet::with_capacity(count as usize);
    for value in 0..count { values.insert(value); }
    let mut checksum = 0_i64;
    for value in 0..count {
        if values.contains(&value) { checksum += value as i64; }
    }
    for value in (0..count).step_by(2) {
        if values.remove(&value) { checksum += 1; }
    }
    (checksum, values.len(), values.capacity())
}

fn main() {
    let _ = workload(10_000);
    let a0 = ALLOCS.load(Ordering::Relaxed);
    let b0 = BYTES.load(Ordering::Relaxed);
    let started = Instant::now();
    let (checksum, len, capacity) = workload(10_000_000);
    let elapsed = started.elapsed().as_nanos();
    println!("checksum={checksum} elapsed_ns={elapsed} len={len} capacity={capacity} allocations={} allocated_bytes={}",
        ALLOCS.load(Ordering::Relaxed) - a0, BYTES.load(Ordering::Relaxed) - b0);
}
