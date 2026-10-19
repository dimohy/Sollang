"""Close a hard-interrupted verification only after measured process shutdown."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--reason", required=True)
    args = parser.parse_args()
    result_path = args.result.resolve()
    if result_path.name != "result.json" or not result_path.is_relative_to(ROOT / "artifacts"):
        raise ValueError("INTERRUPTED_VERIFICATION_RESULT_BOUNDARY_INVALID")
    original = result_path.read_bytes()
    result = json.loads(original)
    if result.get("status") != "running":
        raise ValueError("INTERRUPTED_VERIFICATION_NOT_RUNNING")
    processes = result.get("processes", [])
    if not processes or any(type(row.get("pid")) is not int for row in processes):
        raise ValueError("INTERRUPTED_VERIFICATION_PROCESS_INVENTORY_MISSING")
    pids = [row["pid"] for row in processes]
    owned_path = str(result_path.parent).replace("'", "''")
    command = ("$owned = @(" + ",".join(map(str, pids)) + "); "
               "$excluded = @($PID," + str(os.getpid()) + "," + str(os.getppid()) + "); "
               "@(Get-CimInstance Win32_Process | Where-Object { "
               "$_.ProcessId -notin $excluded -and ($_.ProcessId -in $owned -or "
               "($_.CommandLine -and $_.CommandLine.Contains('" + owned_path + "'))) } | "
               "Select-Object -ExpandProperty ProcessId) | ConvertTo-Json -Compress")
    probe = subprocess.run(["pwsh", "-NoProfile", "-Command", command],
                           capture_output=True, text=True, check=True, timeout=30)
    active = json.loads(probe.stdout) if probe.stdout.strip() else []
    if active:
        raise ValueError("INTERRUPTED_VERIFICATION_PROCESSES_STILL_ACTIVE")
    pins = result.get("inputHashes")
    if not isinstance(pins, dict) or not pins:
        raise ValueError("INTERRUPTED_VERIFICATION_INPUT_INVENTORY_MISSING")
    stable = all(Path(path).is_file() and hashlib.sha256(Path(path).read_bytes()).hexdigest().upper() == digest.upper()
                 for path, digest in pins.items())
    evidence = {"schemaVersion": 1, "status": "shutdown-confirmed", "reason": args.reason,
                "observedAtUtc": datetime.now(timezone.utc).isoformat(), "processIds": pids,
                "activeProcessIds": [], "inputsStable": stable,
                "originalResultSha256": hashlib.sha256(original).hexdigest().upper(),
                "exitCodesUnavailable": [row["pid"] for row in processes if row.get("exit") is None],
                "outputDisposition": "preserve-canceled-unverified-output"}
    backup = result_path.with_name("interrupted-running-result.json")
    evidence_path = result_path.with_name("interrupt-shutdown-result.json")
    if backup.exists() or evidence_path.exists():
        raise ValueError("INTERRUPTED_VERIFICATION_RECOVERY_ALREADY_EXISTS")
    backup.write_bytes(original)
    evidence_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    result.update(status="canceled", inputsStable=stable, processesStopped=True,
                  cancellationReason=args.reason, cancellationShutdownEvidence=str(evidence_path))
    result.pop("activeProcess", None)
    for row in result.get("cases", []):
        if row.get("status") == "running":
            row.update(status="canceled", passed=False)
    for row in processes:
        if row.get("exit") is None:
            row.update(terminationVerified=True, exitCodeUnavailable=True)
    temporary = result_path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    temporary.replace(result_path)
    print(json.dumps({"status": "canceled", "processesStopped": True, "inputsStable": stable,
                      "preservedOutput": str(result_path.parent)}))


if __name__ == "__main__":
    main()
