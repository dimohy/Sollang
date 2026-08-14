export const benchmarkFamilies = [
  { id: 1, name: "linear-sum", category: "integer", inputs: [20000000, 40000000, 60000000, 80000000, 100000000] },
  { id: 2, name: "square-mod", category: "integer", inputs: [10000000, 20000000, 30000000, 40000000, 50000000] },
  { id: 3, name: "affine-recurrence", category: "integer", inputs: [10000000, 20000000, 30000000, 40000000, 50000000] },
  { id: 4, name: "branch-mix", category: "branch", inputs: [20000000, 40000000, 60000000, 80000000, 100000000] },
  { id: 5, name: "gcd-batch", category: "integer", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 6, name: "collatz-total", category: "branch", inputs: [100000, 200000, 300000, 400000, 500000] },
  { id: 7, name: "prime-count", category: "integer", inputs: [20000, 40000, 60000, 80000, 100000] },
  { id: 8, name: "divisor-sum", category: "integer", inputs: [20000, 40000, 60000, 80000, 100000] },
  { id: 9, name: "fibonacci-batch", category: "call", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 10, name: "polynomial-horner", category: "floating-point", inputs: [10000000, 20000000, 30000000, 40000000, 50000000] },
  { id: 11, name: "nested-triangular", category: "loop", inputs: [2000, 4000, 6000, 8000, 10000] },
  { id: 12, name: "minmax-stream", category: "branch", inputs: [20000000, 40000000, 60000000, 80000000, 100000000] },
  { id: 13, name: "array-fill-sum", category: "memory", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 14, name: "array-reverse-sum", category: "memory", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 15, name: "array-stride-sum", category: "memory", inputs: [2000000, 4000000, 6000000, 8000000, 10000000] },
  { id: 16, name: "array-prefix-sum", category: "memory", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 17, name: "insertion-sort", category: "sorting", inputs: [1000, 2000, 3000, 4000, 5000] },
  { id: 18, name: "prime-sieve", category: "memory", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
  { id: 19, name: "matrix-multiply", category: "floating-point", inputs: [48, 64, 80, 96, 112] },
  { id: 20, name: "binary-search", category: "search", inputs: [1000000, 2000000, 3000000, 4000000, 5000000] },
];

export const benchmarkCases = benchmarkFamilies.flatMap((family) =>
  family.inputs.map((input, index) => ({
    id: `${String(family.id).padStart(2, "0")}-${index + 1}`,
    familyId: family.id,
    family: family.name,
    category: family.category,
    profile: index + 1,
    input,
    seed: 55 + index,
  })),
);

if (benchmarkFamilies.length !== 20 || benchmarkCases.length !== 100) {
  throw new Error(`expected 20 families and 100 cases, got ${benchmarkFamilies.length} and ${benchmarkCases.length}`);
}
