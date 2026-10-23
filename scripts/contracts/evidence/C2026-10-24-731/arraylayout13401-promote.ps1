$ErrorActionPreference = 'Stop'
& scripts/promote-compiler-defect-shaping-trace.ps1 `
 -DefectId C2026-10-24-731 -AssetKind invariant `
 -AuthorityPath 'selfhost/semantic/diagnostics.slg:firstPreparedArraySignatureDiagnostic' `
 -Reason 'Current CSharp23, actual SLG23/runtime6 and fresh Native23 passed; original exact no-LLVM guards2 and current original generic pair5 passed. Prepared source type admission preserves child-first storage policy and canonical declaration locations before IR. Canonical baseline failure1 and current invariant success0 are preserved. Only focused implementation is complete; whole-source/runtime, Stage and platform gates remain pending. No performance claim.' `
 -ValidatorEvidence @('scripts/contracts/evidence/C2026-10-24-731/focused-qualification13399.json','scripts/contracts/evidence/C2026-10-24-731/source13390/result.json','scripts/contracts/evidence/C2026-10-24-731/candidate.json') `
 -ConsumerEvidence @('scripts/contracts/evidence/C2026-10-24-731/native13396/result.json','scripts/contracts/evidence/C2026-10-24-731/guards13397/result.json','scripts/contracts/evidence/C2026-10-24-731/generic13398/result.json')
