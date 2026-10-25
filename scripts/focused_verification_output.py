"""Durable process/output supervision for focused verification runners.

Artifact selection and cleanup remain exclusively in completed_artifact_plan.
"""
import hashlib
import os
from pathlib import Path
import subprocess
from verification_json_records import write_json_atomic

from completed_artifact_plan import cleanup_output, initialize_output, assert_output_shutdown, GENERATED


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def lifecycle_inputs(root):
    return [Path(__file__).resolve(), root / "scripts/verification_json_records.py",
            root / "scripts/completed_artifact_plan.py",
            root / "scripts/ArtifactLifecycle.ps1", root / "scripts/Invoke-CompletedArtifactCleanup.ps1",
            root / "scripts/contracts/artifact-lifecycle.json"]


class VerificationOutput:
    def __init__(self, root, output, inputs, result, cleanup_mode="execute", timeout_seconds=180,
                 reusable_directories=None):
        if cleanup_mode not in ("execute", "plan-only") or timeout_seconds <= 0:
            raise ValueError("FOCUSED_OUTPUT_CONFIGURATION_INVALID")
        self.root, self.output = Path(root).resolve(), Path(output).resolve()
        self.reusable_directories = reusable_directories
        initialize_output(self.root, self.output, reusable_directories=reusable_directories)
        self.inputs = list(dict.fromkeys(Path(path).resolve() for path in inputs))
        self.hashes = {str(path): sha(path) for path in self.inputs}
        self.result = result
        self.cleanup_mode, self.timeout = cleanup_mode, timeout_seconds
        self.result.update(status="running", inputSha256=self.hashes, inputHashes=self.hashes, processes=[],
                           artifactCleanupMode=cleanup_mode)
        self.output.mkdir(parents=True, exist_ok=False)
        self.save()

    def save(self):
        write_json_atomic(self.output / "result.json", self.result)

    def stable(self):
        return self.hashes == {str(path): sha(path) if path.is_file() else "MISSING" for path in self.inputs}

    def run(self, command, stdout, stderr):
        if not self.stable():
            raise ValueError("FOCUSED_INPUT_DRIFT")
        with Path(stdout).open("wb") as out, Path(stderr).open("wb") as err:
            process = subprocess.Popen(command, cwd=self.root, stdout=out, stderr=err)
            row = {"pid": process.pid, "command": list(command), "status": "running"}
            self.result["processes"].append(row)
            self.result["activeProcess"] = {"pid": process.pid, "command": list(command)}
            try:
                self.save()
                code = process.wait(timeout=self.timeout)
                row.update(status="exited", exit=code)
                return code
            except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                if os.name == "nt":
                    termination = subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                        capture_output=True, text=True, check=False)
                    row["termination"] = {"exit": termination.returncode,
                        "stdout": termination.stdout, "stderr": termination.stderr}
                else:
                    process.kill()
                    row["termination"] = {"exit": 0}
                process.wait()
                row.update(status="canceled" if isinstance(error, KeyboardInterrupt) else "timed-out",
                           exit=process.returncode)
                raise
            finally:
                self.result.pop("activeProcess", None)
                self.save()

    def __enter__(self):
        return self

    def __exit__(self, kind, error, traceback):
        cases = self.result["cases"]
        rows = list(cases.values()) if isinstance(cases, dict) else cases
        terminal = "canceled" if isinstance(error, KeyboardInterrupt) else (
            "timed-out" if isinstance(error, subprocess.TimeoutExpired) else "failed")
        for row in rows:
            if row.get("status") == "running":
                row.update(status=terminal, passed=False)
        stable = self.stable()
        stopped = not self.result.get("activeProcess") and all(
            isinstance(process.get("exit"), int) for process in self.result["processes"])
        if stopped:
            try:
                assert_output_shutdown(self.root, self.output)
            except ValueError as shutdown_error:
                stopped = False
                self.result["shutdownFailure"] = str(shutdown_error)
        complete = sum(row.get("passed") is True for row in rows)
        self.result.update(inputStable=stable, inputsStable=stable, processesStopped=stopped, completed=complete)
        success = error is None and stable and stopped and complete == self.result["total"]
        self.result["status"] = "passed" if success else terminal
        if error is not None:
            self.result["failure"] = f"{type(error).__name__}: {error}"
        elif not stable:
            self.result["failure"] = "FOCUSED_INPUT_DRIFT"
        self.result["generatedOutputHashes"] = {str(path): sha(path) for path in self.output.rglob("*")
            if path.is_file() and (GENERATED.search(path.name)
                                  or ".sollang-cache" in path.parts)}
        self.save()
        if success:
            selection = ({} if self.reusable_directories is None else
                         {"reusable_directories": self.reusable_directories})
            cleanup_output(self.root, self.output, execute=self.cleanup_mode == "execute", **selection)
        return False
