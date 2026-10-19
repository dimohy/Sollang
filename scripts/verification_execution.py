"""Durable, pinned execution for focused Python verification commands."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from completed_artifact_plan import GENERATED, assert_output_shutdown, cleanup_output
from verification_json_records import write_json_atomic


class _WindowsJob:
    """Own every descendant before the suspended root can create children."""
    def __init__(self):
        import ctypes
        from ctypes import wintypes
        self.ctypes = ctypes
        self.api = ctypes.WinDLL('kernel32', use_last_error=True)
        self.api.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
        self.api.CreateJobObjectW.restype = wintypes.HANDLE
        self.api.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
        self.api.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
        self.api.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p]
        self.api.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
        self.api.CloseHandle.argtypes = [wintypes.HANDLE]
        self.api.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
        self.api.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
        self.api.OpenThread.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        self.api.OpenThread.restype = wintypes.HANDLE
        self.api.ResumeThread.argtypes = [wintypes.HANDLE]
        self.api.ResumeThread.restype = wintypes.DWORD
        class ThreadEntry(ctypes.Structure):
            _fields_ = [('size', wintypes.DWORD), ('usage', wintypes.DWORD),
                ('thread', wintypes.DWORD), ('owner', wintypes.DWORD),
                ('basePriority', wintypes.LONG), ('deltaPriority', wintypes.LONG), ('flags', wintypes.DWORD)]
        self.thread_entry = ThreadEntry
        self.api.Thread32First.argtypes = [wintypes.HANDLE, ctypes.POINTER(ThreadEntry)]
        self.api.Thread32Next.argtypes = [wintypes.HANDLE, ctypes.POINTER(ThreadEntry)]
        class ProcessIds(ctypes.Structure):
            _fields_ = [('assigned', wintypes.DWORD), ('count', wintypes.DWORD),
                ('ids', ctypes.c_size_t * 64)]
        self.process_ids = ProcessIds
        class Limits(ctypes.Structure):
            _fields_ = [('user', ctypes.c_int64), ('job', ctypes.c_int64),
                ('flags', wintypes.DWORD), ('minWorking', ctypes.c_size_t), ('maxWorking', ctypes.c_size_t),
                ('activeLimit', wintypes.DWORD), ('affinity', ctypes.c_size_t),
                ('priority', wintypes.DWORD), ('scheduling', wintypes.DWORD)]
        class Extended(ctypes.Structure):
            _fields_ = [('basic', Limits), ('io', ctypes.c_uint64 * 6),
                ('processMemory', ctypes.c_size_t), ('jobMemory', ctypes.c_size_t),
                ('peakProcess', ctypes.c_size_t), ('peakJob', ctypes.c_size_t)]
        class Accounting(ctypes.Structure):
            _fields_ = [('times', ctypes.c_int64 * 4), ('faults', wintypes.DWORD),
                ('total', wintypes.DWORD), ('active', wintypes.DWORD), ('terminated', wintypes.DWORD)]
        self.accounting = Accounting
        self.handle = self.api.CreateJobObjectW(None, None)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = Extended()
        limits.basic.flags = 0x2000  # KILL_ON_JOB_CLOSE; breakaway is not enabled.
        if not self.api.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            error = ctypes.WinError(ctypes.get_last_error())
            self.close()
            raise error

    def start(self, process):
        try:
            if not self.api.AssignProcessToJobObject(self.handle, int(process._handle)):
                raise self.ctypes.WinError(self.ctypes.get_last_error())
            self.resume_primary_thread(process.pid)
        except Exception:
            process.kill()
            process.wait(timeout=5)
            raise

    def resume_primary_thread(self, pid):
        snapshot = self.api.CreateToolhelp32Snapshot(4, 0)
        if snapshot == self.ctypes.c_void_p(-1).value:
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        try:
            entry = self.thread_entry()
            entry.size = self.ctypes.sizeof(entry)
            threads = []
            found = self.api.Thread32First(snapshot, self.ctypes.byref(entry))
            while found:
                if entry.owner == pid:
                    threads.append(entry.thread)
                found = self.api.Thread32Next(snapshot, self.ctypes.byref(entry))
            if self.ctypes.get_last_error() != 18:  # ERROR_NO_MORE_FILES
                raise self.ctypes.WinError(self.ctypes.get_last_error())
            if len(threads) != 1:
                raise OSError('VERIFICATION_SUSPENDED_PRIMARY_THREAD_NOT_UNIQUE')
            thread = self.api.OpenThread(2, False, threads[0])
            if not thread:
                raise self.ctypes.WinError(self.ctypes.get_last_error())
            try:
                previous = self.api.ResumeThread(thread)
                if previous == 0xffffffff:
                    raise self.ctypes.WinError(self.ctypes.get_last_error())
                if previous != 1:
                    raise OSError('VERIFICATION_PRIMARY_THREAD_SUSPEND_COUNT_INVALID')
            finally:
                self.api.CloseHandle(thread)
        finally:
            self.api.CloseHandle(snapshot)

    def account(self):
        data = self.accounting()
        if not self.api.QueryInformationJobObject(self.handle, 1, self.ctypes.byref(data), self.ctypes.sizeof(data), None):
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        return data

    def stopped(self):
        return self.account().active == 0

    def shutdown_observation(self):
        active = self.account().active
        if active == 0:
            return active, []
        pids = self.process_ids()
        if not self.api.QueryInformationJobObject(self.handle, 3, self.ctypes.byref(pids), self.ctypes.sizeof(pids), None):
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        if pids.count > 64 or pids.assigned != pids.count:
            raise ValueError('OWNED_SHUTDOWN_PID_SAMPLE_BUDGET_EXCEEDED')
        return active, list(pids.ids[:pids.count])

    def cpu_observation(self):
        data = self.account()
        pids = self.process_ids()
        if not self.api.QueryInformationJobObject(self.handle, 3, self.ctypes.byref(pids), self.ctypes.sizeof(pids), None):
            raise self.ctypes.WinError(self.ctypes.get_last_error())
        if pids.count > 64 or pids.assigned != pids.count:
            raise ValueError('OWNED_CPU_PID_SAMPLE_BUDGET_EXCEEDED')
        return (data.times[0] + data.times[1]) / 10000000, list(pids.ids[:pids.count])

    def terminate(self):
        if not self.api.TerminateJobObject(self.handle, 137):
            raise self.ctypes.WinError(self.ctypes.get_last_error())

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None


class VerificationExecution:
    def __init__(self, repo, output, result, stable, sha, *, record_path=None):
        output_root = output.resolve()
        destination = output / "result.json" if record_path is None else Path(record_path)
        if record_path is not None and not destination.is_absolute():
            destination = output / destination
        destination = destination.resolve()
        if destination == output_root or not destination.is_relative_to(output_root):
            raise ValueError("EXECUTION_RECORD_OUTSIDE_OUTPUT")
        if result.get("processes") or result.get("activeProcess") is not None:
            raise ValueError("EXECUTION_REINITIALIZATION_HAS_PROCESS_EVIDENCE")
        self.record_path = destination
        self.repo, self.output, self.result = repo, output, result
        self.stable, self.sha = stable, sha
        self.result["processes"] = []

    def save(self):
        write_json_atomic(self.record_path, self.result)

    @staticmethod
    def group_stopped(group):
        """Linux zombies cannot execute or write; other POSIX hosts fail closed."""
        try:
            os.killpg(group, 0)
        except ProcessLookupError:
            return True
        if sys.platform == "linux":
            for entry in Path('/proc').iterdir():
                if not entry.name.isdigit():
                    continue
                try:
                    fields = (entry / 'stat').read_text().rpartition(')')[2].split()
                except FileNotFoundError:
                    continue
                if int(fields[2]) == group and fields[0] not in ('Z', 'X'):
                    return False
            return True
        return False

    def confirm_shutdown(self, process, row, job=None):
        if process.poll() is None or row.get('terminationFailure'):
            return False
        try:
            if os.name == 'nt':
                return job is not None and job.stopped()
            return self.group_stopped(process.pid)
        except (OSError, ValueError, IndexError) as error:
            row['shutdownFailure'] = f'{type(error).__name__}: {error}'
            return False

    def confirm_natural_shutdown(self, process, row, job=None):
        if os.name != 'nt':
            return self.confirm_shutdown(process, row, job)
        if process.poll() is None or job is None or row.get('terminationFailure'):
            return False
        # Waiting on the retained root handle can precede Job accounting drain.
        # Real non-root members still fail immediately; only exited-root/empty
        # membership may settle within the existing five-second shutdown budget.
        deadline = time.monotonic() + 5
        record = dict(rootPid=process.pid, budgetSeconds=5, observedSamples=0,
                      samples=[], outcome='unconfirmed')
        row['naturalShutdownObservation'] = record
        while True:
            try:
                active, pids = job.shutdown_observation()
            except (OSError, ValueError, IndexError) as error:
                row['shutdownFailure'] = f'{type(error).__name__}: {error}'
                record['outcome'] = 'query-failed'
                return False
            sample = dict(activeProcesses=active, ownedPids=pids)
            record['observedSamples'] += 1
            if len(record['samples']) < 8:
                record['samples'].append(sample)
            else:
                record['samples'][-1] = sample
            if active == 0:
                record['outcome'] = 'drained'
                return True
            if any(pid != process.pid for pid in pids):
                record['outcome'] = 'live-descendant'
                return False
            if time.monotonic() >= deadline:
                record['outcome'] = 'root-accounting-unconfirmed'
                return False
            time.sleep(0.02)

    @staticmethod
    def cpu_observation(pid, job=None):
        if job is not None:
            seconds, pids = job.cpu_observation()
        elif sys.platform == 'linux':
            ticks, pids = 0, []
            for entry in Path('/proc').iterdir():
                if not entry.name.isdigit():
                    continue
                try:
                    fields = (entry / 'stat').read_text().rpartition(')')[2].split()
                except FileNotFoundError:
                    continue
                if int(fields[2]) == pid and fields[0] not in ('Z', 'X'):
                    pids.append(int(entry.name))
                    ticks += int(fields[11]) + int(fields[12])
            seconds = ticks / os.sysconf('SC_CLK_TCK')
        else:
            return None, 'unknown', [pid]
        pids = sorted(set([pid, *pids]))  # The root remains the observation anchor after exit.
        if len(pids) > 64:
            raise ValueError('OWNED_CPU_PID_SAMPLE_BUDGET_EXCEEDED')
        return seconds, 'owned-tree', pids

    def run_program(self, executable, case, prefix, timeout=30) -> subprocess.CompletedProcess:
        """Execute a planned program with its declared argv, without shell parsing."""
        arguments = case.get("arguments", [])
        if not isinstance(arguments, list) or any(not isinstance(arg, str) for arg in arguments):
            raise ValueError("PROGRAM_CASE_ARGUMENTS_INVALID")
        return self.run([str(executable), *arguments], prefix, timeout=timeout)

    def run(self, command, prefix, timeout=180, diagnostics=None) -> subprocess.CompletedProcess:
        """Return captured command evidence; callers must check .returncode and oracles.

        A CompletedProcess object is truthy even for exit zero. It is not an
        integer exit code and does not itself certify verification success.
        """
        if diagnostics is not None and diagnostics.hard_timeout_seconds != timeout:
            raise ValueError('DIAGNOSTIC_HARD_TIMEOUT_MISMATCH')
        if not self.stable():
            raise ValueError("INPUT_DRIFT before " + str(prefix))
        prefix = Path(prefix)
        stdout_path, stderr_path = prefix.with_suffix(".stdout"), prefix.with_suffix(".stderr")
        with stdout_path.open("wb") as out, stderr_path.open("wb") as err:
            job = _WindowsJob() if os.name == 'nt' else None
            try:
                process = subprocess.Popen(command, cwd=self.repo, stdout=out, stderr=err,
                    start_new_session=os.name != 'nt', creationflags=4 if job is not None else 0)
            except Exception:
                if job is not None:
                    job.close()
                raise
            row = {"pid": process.pid, "command": command, "shutdownConfirmed": False,
                   "shutdownScope": 'owned-windows-job' if job is not None else 'owned-posix-process-group',
                   "startedAtUtc": datetime.now(timezone.utc).isoformat()}
            started = time.monotonic()

            def observe(elapsed=None):
                if diagnostics is not None:
                    try:
                        cpu, scope, pids = self.cpu_observation(process.pid, job)
                    except (OSError, ValueError, IndexError) as cpu_error:
                        row['cpuObservationFailure'] = f'{type(cpu_error).__name__}: {cpu_error}'
                        cpu, scope, pids = None, 'unknown', [process.pid]
                    row['cpuIdentity'] = {'kind': row['shutdownScope'], 'rootPid': process.pid,
                        'rootIsObservationAnchor': True,
                        'counter': 'all-job-members-including-exited' if job is not None else 'currently-observed-group-members',
                        'limitations': ['PID membership and CPU counters are sampled separately.',
                            'PID changes or counter resets interrupt CPU delta continuity.']}
                    row['diagnostics'] = diagnostics.observe(time.monotonic() - started if elapsed is None else elapsed,
                        process.pid, stdout_path.stat().st_size, stderr_path.stat().st_size,
                        cpu_seconds=cpu, cpu_scope=scope, owned_pids=pids)
                    self.save()
            self.result["processes"].append(row)
            self.result["activeProcess"] = row
            try:
                self.save()
                if job is not None:
                    job.start(process)
                if diagnostics is None:
                    process.wait(timeout=timeout)
                else:
                    observe(0)
                    deadline = started + timeout
                    while True:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            raise subprocess.TimeoutExpired(command, timeout)
                        try:
                            process.wait(timeout=min(remaining, diagnostics.sample_interval_seconds))
                            break
                        except subprocess.TimeoutExpired:
                            observe()
                if not self.confirm_natural_shutdown(process, row, job):
                    descendant = (os.name != 'nt' or row.get('naturalShutdownObservation', {}).get('outcome') == 'live-descendant')
                    row['descendantOutlivedParent'] = descendant
                    self.result.setdefault('terminatedProcesses', []).append({
                        'pid': process.pid, 'reason': 'DescendantOutlivedParent' if descendant else 'ShutdownUnconfirmed',
                        'scope': row['shutdownScope']})
                    if job is not None:
                        job.terminate()
                    else:
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    deadline = time.monotonic() + 5
                    while not self.confirm_shutdown(process, row, job) and time.monotonic() < deadline:
                        if row.get('shutdownFailure'):
                            break
                        time.sleep(0.02)
                    raise ValueError('PROCESS_DESCENDANT_OUTLIVED_PARENT' if descendant else 'PROCESS_SHUTDOWN_UNCONFIRMED')
            except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                termination_record = {"pid": process.pid, "reason": type(error).__name__}
                self.result.setdefault("terminatedProcesses", []).append(termination_record)
                try:
                    if os.name == "nt":
                        job.terminate()
                        # Saving the initial record can fail before the suspended
                        # root is assigned to the job. Its retained handle is ours.
                        if process.poll() is None:
                            process.kill()
                        termination_record.update(exit=0, scope='owned-windows-job')
                    else:
                        try:
                            os.killpg(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    process.wait(timeout=5)
                    deadline = time.monotonic() + 5
                    while not self.confirm_shutdown(process, row, job) and time.monotonic() < deadline:
                        if row.get('terminationFailure') or row.get('shutdownFailure'):
                            break
                        time.sleep(0.02)
                except (OSError, subprocess.TimeoutExpired) as termination_error:
                    row['terminationFailure'] = f'{type(termination_error).__name__}: {termination_error}'
                    termination_record['failure'] = row['terminationFailure']
                raise
            except Exception:
                # A logging/diagnostic failure must not abandon a started owner.
                if not self.confirm_shutdown(process, row, job):
                    try:
                        if job is not None:
                            job.terminate()
                            if process.poll() is None:
                                process.kill()
                        else:
                            try:
                                os.killpg(process.pid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                        process.wait(timeout=5)
                        deadline = time.monotonic() + 5
                        while not self.confirm_shutdown(process, row, job) and time.monotonic() < deadline:
                            if row.get('shutdownFailure'):
                                break
                            time.sleep(0.02)
                    except (OSError, subprocess.TimeoutExpired) as termination_error:
                        row['terminationFailure'] = f'{type(termination_error).__name__}: {termination_error}'
                raise
            finally:
                active_error = sys.exc_info()[1]
                row["exit"] = process.returncode
                row['finishedAtUtc'] = datetime.now(timezone.utc).isoformat()
                row['durationMilliseconds'] = round((time.monotonic() - started) * 1000)
                row['shutdownConfirmed'] = self.confirm_shutdown(process, row, job)
                self.result.pop("activeProcess", None)
                try:
                    # Preserve the original failure if the observer itself failed.
                    try:
                        observe()
                    except Exception as diagnostic_error:
                        row['diagnosticFailure'] = f'{type(diagnostic_error).__name__}: {diagnostic_error}'
                        if active_error is None:
                            raise
                    self.save()
                finally:
                    if job is not None:
                        job.close()
        return subprocess.CompletedProcess(command, process.returncode,
            stdout_path.read_text(encoding="utf-8-sig", errors="replace"),
            stderr_path.read_text(encoding="utf-8-sig", errors="replace"))

    def finalize(self, error=None, *, cleanup=True):
        self.result["inputsStable"] = self.stable()
        if error is not None:
            self.result["status"] = ("canceled" if isinstance(error, KeyboardInterrupt)
                else "timed-out" if isinstance(error, subprocess.TimeoutExpired) else "failed")
            self.result["failure"] = f"{type(error).__name__}: {error}"
        elif not self.result["inputsStable"]:
            self.result["status"] = "failed"
            self.result["failure"] = "INPUT_DRIFT after cases"
        elif self.result.get("status") == "running":
            self.result["status"] = "failed"
            self.result["failure"] = "EXECUTION_TERMINAL_STATUS_REQUIRED"
        self.result["processesStopped"] = not self.result.get("activeProcess") and all(
            isinstance(row.get("exit"), int) and row.get('shutdownConfirmed') is True
            for row in self.result["processes"])
        if not self.result['processesStopped'] and error is None:
            self.result.update(status='failed', failure='PROCESS_SHUTDOWN_UNCONFIRMED')
        self.result["generatedOutputHashes"] = {
            str(path): self.sha(path) for path in self.output.rglob("*") if path.is_file()
            and (GENERATED.search(path.name) or ".sollang-cache" in path.parts)}
        self.save()
        if (cleanup and self.result["status"] == "passed" and self.result["inputsStable"]
                and self.result["processesStopped"]):
            assert_output_shutdown(self.repo, self.output)
            cleanup_output(self.repo, self.output, execute=True)
