"""Bounded, unbuffered call-boundary observations; never acceptance evidence."""

import argparse
import hashlib
import json
import re
from pathlib import Path


FUNCTION = re.compile(r"^define [^\n]*@([A-Za-z0-9_.$]+)\([^\n]*\)(?: #[0-9]+)? \{\n(.*?)^}", re.M | re.S)
CALL = re.compile(r"\bcall\b[^\n]*?@([A-Za-z0-9_.$]+)\(")


def instrument(source: str, root: str, depth: int, limit: int, owner_prefix: str = "", abi: str = "selfhost", excluded_callees=(), observed_owners=(), additional_roots=(), *, first_visit_only=False, power_of_two_visits=False, phase_boundaries_only=False):
    if type(first_visit_only) is not bool:
        raise ValueError("LLVM_TRACE_FIRST_VISIT_MODE_INVALID")
    if type(power_of_two_visits) is not bool or (power_of_two_visits and first_visit_only):
        raise ValueError("LLVM_TRACE_SPARSE_VISIT_MODE_INVALID")
    if type(phase_boundaries_only) is not bool or (phase_boundaries_only and power_of_two_visits):
        raise ValueError("LLVM_TRACE_PHASE_MODE_INVALID")
    if abi not in ("selfhost", "managed-windows"):
        raise ValueError("LLVM_TRACE_ABI_INVALID")
    source = source.replace("\r\n", "\n")
    symbol_prefix = "sollang_m" if abi == "selfhost" else "sollang_fn_"
    functions = {}
    for match in FUNCTION.finditer(source):
        name = match.group(1)
        if name in functions:
            raise ValueError("LLVM_TRACE_DUPLICATE_FUNCTION: " + name)
        functions[name] = match
    if root not in functions or "entry:\n" not in functions[root].group(2):
        raise ValueError("LLVM_TRACE_ROOT_MISSING: " + root)
    excluded_callees = frozenset(excluded_callees)
    for callee in excluded_callees:
        if callee not in functions or not callee.startswith(symbol_prefix) or callee == root:
            raise ValueError("LLVM_TRACE_EXCLUDED_CALLEE_INVALID: " + callee)
    if not 0 <= depth <= 4 or not 1 <= limit <= (8192 if power_of_two_visits else 1024):
        raise ValueError("LLVM_TRACE_BOUND_INVALID")
    owner_pattern = r"sollang_m\d+_" if abi == "selfhost" else r"sollang_fn_[A-Za-z0-9_]*"
    if owner_prefix and (not root.startswith(owner_prefix) or not re.fullmatch(owner_pattern, owner_prefix)):
        raise ValueError("LLVM_TRACE_OWNER_PREFIX_INVALID")
    writer_valid = ("define internal void @sollang_runtime_eprint(" in source if abi == "selfhost" else
                    "declare dllimport ptr @GetStdHandle(i32)" in source
                    and "declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)" in source)
    if "@sollang_observation_" in source or not writer_valid:
        raise ValueError("LLVM_TRACE_RUNTIME_INVALID")
    additional_roots = tuple(additional_roots)
    if (len(additional_roots) > 4 or any(not isinstance(name, str) for name in additional_roots)
            or len(set(additional_roots)) != len(additional_roots)
            or any(name == root or name not in functions or not name.startswith(symbol_prefix)
                   or "entry:\n" not in functions[name].group(2) for name in additional_roots)):
        raise ValueError("LLVM_TRACE_ADDITIONAL_ROOTS_INVALID")
    owners = {root, *additional_roots}
    frontier = set(owners)
    for _ in range(depth):
        frontier = {callee for owner in frontier for callee in CALL.findall(functions[owner].group(2))
                    if callee in functions and callee.startswith(symbol_prefix) and callee not in owners}
        owners.update(frontier)
    if owner_prefix:
        owners = {owner for owner in owners if owner.startswith(owner_prefix)}
    if observed_owners:
        selected = set(observed_owners)
        if root not in selected or not selected.issubset(owners):
            raise ValueError("LLVM_TRACE_EXPLICIT_OWNERS_INVALID")
        owners = selected
    if not set(additional_roots).issubset(owners):
        raise ValueError("LLVM_TRACE_ADDITIONAL_ROOTS_SCOPE_MISSING")
    if len(owners) > 128:
        raise ValueError("LLVM_TRACE_FUNCTION_LIMIT")
    markers = []
    constants = []

    def marker(label):
        index = len(markers)
        if first_visit_only or power_of_two_visits:
            label = f"site:{index}:" + label
        data = label.encode("ascii")
        markers.append({"id": index, "label": label})
        constants.append(f'@sollang_observation_label_{index} = private constant [{len(data)} x i8] c"{label}"')
        if first_visit_only:
            return (f"  call void @sollang_observation_emit_once(i32 {index}, "
                    f"ptr @sollang_observation_label_{index}, i64 {len(data)})")
        if power_of_two_visits:
            return (f"  call void @sollang_observation_emit_sparse(i32 {index}, "
                    f"ptr @sollang_observation_label_{index}, i64 {len(data)})")
        return f"  call void @sollang_observation_emit(ptr @sollang_observation_label_{index}, i64 {len(data)})"

    def replace(match):
        owner = match.group(1)
        if owner not in owners:
            return match.group(0)
        lines = match.group(0).splitlines()
        output = []
        for line in lines:
            output.append(line)
            if line == "entry:" and (owner == root or phase_boundaries_only):
                if owner == root:
                    output.append("  store i1 true, ptr @sollang_observation_active, align 1")
                output.append(marker("enter:" + owner))
                continue
            if phase_boundaries_only:
                if line.strip().startswith("ret "):
                    output.pop()
                    output.extend([marker("exit:" + owner), line])
                continue
            call = CALL.search(line)
            if call and call.group(1).startswith(symbol_prefix) and call.group(1) not in excluded_callees:
                output.pop()
                label = owner + "->" + call.group(1)
                output.extend([marker("before:" + label), line, marker("after:" + label)])
        return "\n".join(output)

    transformed = FUNCTION.sub(replace, source)
    if first_visit_only and len(markers) > limit:
        raise ValueError("LLVM_TRACE_FIRST_VISIT_STATIC_BUDGET_REQUIRED")
    if power_of_two_visits and len(markers) > 1024:
        raise ValueError("LLVM_TRACE_SPARSE_STATIC_BUDGET_REQUIRED")
    writer = "  call void @sollang_runtime_eprint(ptr %data, i64 %length, i1 true)"
    if abi == "managed-windows":
        writer = """  %handle = call ptr @GetStdHandle(i32 -12)
  %written = alloca i32, align 4
  %length32 = trunc i64 %length to i32
  %write = call i32 @WriteFile(ptr %handle, ptr %data, i32 %length32, ptr %written, ptr null)
  %newline = call i32 @WriteFile(ptr %handle, ptr @sollang_observation_newline, i32 1, ptr %written, ptr null)"""
        constants.append('@sollang_observation_newline = private constant [1 x i8] c"\\0A"')
    runtime = f"""
@sollang_observation_active = private global i1 false
@sollang_observation_count = private global i32 0
define internal void @sollang_observation_emit(ptr %data, i64 %length) {{
entry:
  %active = load i1, ptr @sollang_observation_active, align 1
  %count = load i32, ptr @sollang_observation_count, align 4
  %bounded = icmp ult i32 %count, {limit}
  %enabled = and i1 %active, %bounded
  br i1 %enabled, label %emit, label %done
emit:
  %next = add i32 %count, 1
  store i32 %next, ptr @sollang_observation_count, align 4
{writer}
  br label %done
done:
  ret void
}}
"""
    if first_visit_only:
        runtime += f"""
@sollang_observation_seen = private global [{len(markers)} x i1] zeroinitializer
define internal void @sollang_observation_emit_once(i32 %site, ptr %data, i64 %length) {{
entry:
  %active = load i1, ptr @sollang_observation_active, align 1
  %slot = getelementptr [{len(markers)} x i1], ptr @sollang_observation_seen, i32 0, i32 %site
  %seen = load i1, ptr %slot, align 1
  %unseen = xor i1 %seen, true
  %enabled = and i1 %active, %unseen
  br i1 %enabled, label %emit, label %done
emit:
  store i1 true, ptr %slot, align 1
  call void @sollang_observation_emit(ptr %data, i64 %length)
  br label %done
done:
  ret void
}}
"""
    if power_of_two_visits:
        runtime += f"""
@sollang_observation_visits = private global [{len(markers)} x i64] zeroinitializer
define internal void @sollang_observation_emit_sparse(i32 %site, ptr %data, i64 %length) {{
entry:
  %active = load i1, ptr @sollang_observation_active, align 1
  br i1 %active, label %count, label %done
count:
  %slot = getelementptr [{len(markers)} x i64], ptr @sollang_observation_visits, i32 0, i32 %site
  %previous = load i64, ptr %slot, align 8
  %next = add i64 %previous, 1
  store i64 %next, ptr %slot, align 8
  %bits = and i64 %next, %previous
  %power = icmp eq i64 %bits, 0
  br i1 %power, label %emit, label %done
emit:
  call void @sollang_observation_emit(ptr %data, i64 %length)
  br label %done
done:
  ret void
}}
"""
    return transformed + "\n" + "\n".join(constants) + runtime, sorted(owners), markers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--depth", type=int, default=2)
    parser.add_argument("--limit", type=int, default=128)
    parser.add_argument("--owner-prefix", default="", help="Explicit module prefix to avoid unrelated hot-loop trace noise")
    parser.add_argument("--abi", choices=("selfhost", "managed-windows"), default="selfhost")
    parser.add_argument("--exclude-callee", action="append", default=[], help="Exact existing callee whose calls remain intact but are not traced")
    parser.add_argument("--owner", action="append", default=[], help="Exact owner reachable within depth; include the root")
    parser.add_argument("--additional-root", action="append", default=[], help="Up to four explicit phase roots, each with the same bounded depth; only the primary root activates recording")
    visits = parser.add_mutually_exclusive_group()
    visits.add_argument("--first-visit-only", action="store_true", help="Single-thread diagnostic: record each static boundary once; does not measure later loop iterations")
    visits.add_argument("--power-of-two-visits", action="store_true", help="Single-thread diagnostic: record visits1,2,4,8,... per boundary within the global record limit; intervals between powers are unobserved")
    parser.add_argument("--phase-boundaries-only", action="store_true", help="Observe selected function entry/return only; do not inject observations in inner call loops")
    args = parser.parse_args()
    manifest = args.output.with_suffix(".trace.json")
    if args.output.exists() or manifest.exists():
        raise ValueError("LLVM_TRACE_OUTPUT_EXISTS")
    original = args.input.read_bytes()
    result, owners, markers = instrument(original.decode("utf-8-sig"), args.root, args.depth, args.limit, args.owner_prefix, args.abi, args.exclude_callee, args.owner, args.additional_root, first_visit_only=args.first_visit_only, power_of_two_visits=args.power_of_two_visits, phase_boundaries_only=args.phase_boundaries_only)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(result, encoding="utf-8")
    record = {"schemaVersion": 1, "scope": "diagnostic-only-not-acceptance", "input": str(args.input.resolve()),
              "inputSha256": hashlib.sha256(original).hexdigest().upper(), "root": args.root,
              "depth": args.depth, "additionalRoots": args.additional_root, "ownerPrefix": args.owner_prefix, "abi": args.abi, "excludedCallees": sorted(set(args.exclude_callee)), "maximumRecords": args.limit, "owners": owners, "markers": markers,
              "firstVisitOnly": args.first_visit_only,
              "powerOfTwoVisits": args.power_of_two_visits,
              "phaseBoundariesOnly": args.phase_boundaries_only,
              "temporalCoverage": ("selected function entry/return only; inner loops uninstrumented" if args.phase_boundaries_only else "power-of-two visits per static boundary; intervals between powers unobserved" if args.power_of_two_visits else "first visit per static boundary" if args.first_visit_only else "bounded call sequence"),
              "outputSha256": hashlib.sha256(args.output.read_bytes()).hexdigest().upper()}
    manifest.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"owners": len(owners), "markers": len(markers), "maximumRecords": args.limit}))


if __name__ == "__main__":
    main()
