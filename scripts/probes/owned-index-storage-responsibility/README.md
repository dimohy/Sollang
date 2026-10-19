# Owned-index storage responsibility regression

`scripts/contracts/owned-index-storage-responsibility.json` freezes five exact
managed/native cases: local and imported nested scalar structs, fixed-array and
dynamic-array fields, and a bounded scalar-array field. Copyable structs must
remain copyable even when their nominal type has an affine/drop trait.

Run the managed cases first with a new output directory:

```powershell
python scripts/verify-c385-preir-call-numeric.py --mode managed --contract scripts/contracts/owned-index-storage-responsibility.json --format-compiler src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe --output artifacts/scratch/owned-storage-managed-RUN_ID
```

After recording the C# versus SLG source comparison and rebuilding the current
self-host compiler, run the same contract in paired mode. Supply the successful
managed result, source-comparison record, and verified compiler build directory:

```powershell
python scripts/verify-c385-preir-call-numeric.py --mode paired --contract scripts/contracts/owned-index-storage-responsibility.json --format-compiler BUILD_DIR/compiler.exe --build BUILD_DIR --managed-proof artifacts/scratch/owned-storage-managed-RUN_ID/result.json --source-comparison SOURCE_COMPARISON.json --output artifacts/scratch/owned-storage-paired-RUN_ID
```

The paired runner supplies the repository's full `stdlib` to actual native
compilation. This is required: native70 failed in `std/net/http/body.slg` while
compiling an unrelated predicate because `http.Field` contains only two scalar
`Span` fields. Passing an isolated compiler-logic driver cannot close this
regression. `nativeAcceptance` in the contract documents the requirement;
the runner's actual paired compilation and structured result establish it.

`checked.slg`, `source-controls.slg`, and `classifier-controls.slg` retain the
source-decision checks: ten exact owned-index diagnostics, eleven readonly/place
controls, two mut/move `len` shadow rejection controls, and ten storage-classifier
branch checks. Their driver contract must
pin the current self-host source closure and a fresh successful focused semantic
preflight before emission. Keep these source checks distinct from the five
full-stdlib paired cases above. Preserve failed outputs and use the runner's
artifact lifecycle cleanup for successfully completed outputs.

Three further controls map the retained mut/move shadow and ordinary binding
fixtures and check the selected semantic type and AST token location exactly.
Flow shadows retain `[Int; ~]` at the member dot; ordinary binding retains the
indexed `Entry` at the bracket. These checks preserve the distinct C# decisions.

Before rebuilding the native compiler, execute the current SLG semantic decision
over every current stdlib file. The retained template maps the sorted files into
the actual semantic package and reports the diagnostic and active/inactive body
counts using the compiler's `declarationBodyIsActive` decision. It also invokes
the existing `llvmText.validateCheckedFiles(paths, 0)` boundary on the same complete
path list and requires zero blocking semantic/ownership and IR diagnostics before
LLVM output. `checkedSemanticDiagnosticCount` preserves this actual return value:

```powershell
python scripts/verify-owned-index-full-stdlib-source-preflight.py --compiler src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe --llvm .tools/llvm-22.1.8 --output artifacts/scratch/owned-storage-full-stdlib-RUN_ID
```

The result pins the canonical compiler manifest, every compiler and stdlib file,
the generated driver and source manifest, tools, and actual execution JSON/stdout.
Supply its `result.json` through the build runner's required
`-StdlibSourceProofRecord`. A diagnostic, warning, input drift, validation failure,
or cleanup failure leaves a failed proof. The native paired cases remain required
after the build.

`scripts/contracts/owned-index-builtin-borrow.json` retains the C# first proof for
builtin `len` borrowing and mut/move shadows. Rejection source decisions and exact
paired diagnostic text are separate checks.
