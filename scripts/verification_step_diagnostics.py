"""Bounded observations of one verification step; never execute or retry work.

Elapsed time establishes slowness. CPU and log observations only describe
activity in their explicitly supplied scope, not a cause or an improvement.
"""

from __future__ import annotations

import json
import math
from pathlib import Path


def _number(value, name, *, positive=False):
    if (isinstance(value, bool) or not isinstance(value, (int, float))
            or not math.isfinite(value) or value < 0 or (positive and value == 0)):
        raise ValueError(f"STEP_DIAGNOSTICS_INVALID_{name}")
    return value


class SlowStepDiagnostics:
    """Caller supplies timing, owned PIDs, log sizes and optional measured CPU.

    The caller owns sampling and process lifetime. Missing CPU remains unknown;
    process CPU is never relabeled as tree CPU. Configuration is validated before
    any observation or file write. Storage retains the first and latest samples.
    """

    def __init__(self, plan: dict, output_path: Path | None = None, *, timeout_seconds=None):
        keys = {"stage", "softLimitSeconds", "hardTimeoutSeconds",
                "sampleIntervalSeconds", "maxSamples"}
        if not isinstance(plan, dict) or set(plan) != keys:
            raise ValueError("STEP_DIAGNOSTICS_INVALID_PLAN_FIELDS")
        if (not isinstance(plan["stage"], str) or not plan["stage"].strip()
                or len(plan["stage"]) > 128):
            raise ValueError("STEP_DIAGNOSTICS_INVALID_STAGE")
        self.soft_limit_seconds = _number(plan["softLimitSeconds"], "SOFT_LIMIT", positive=True)
        self.hard_timeout_seconds = _number(plan["hardTimeoutSeconds"], "HARD_TIMEOUT", positive=True)
        self.declared_hard_timeout_seconds = self.hard_timeout_seconds
        self.sample_interval_seconds = _number(plan["sampleIntervalSeconds"], "SAMPLE_INTERVAL", positive=True)
        if (self.soft_limit_seconds >= self.hard_timeout_seconds
                or self.sample_interval_seconds > self.hard_timeout_seconds):
            raise ValueError("STEP_DIAGNOSTICS_INVALID_TIME_ORDER")
        if (isinstance(plan["maxSamples"], bool) or not isinstance(plan["maxSamples"], int)
                or plan["maxSamples"] < 2):
            raise ValueError("STEP_DIAGNOSTICS_INVALID_MAX_SAMPLES")
        self.plan = dict(plan)
        if timeout_seconds is not None:
            timeout_seconds = _number(timeout_seconds, "BOUND_TIMEOUT", positive=True)
            if timeout_seconds > self.hard_timeout_seconds:
                raise ValueError("STEP_DIAGNOSTICS_BOUND_EXCEEDS_PLAN")
            self.hard_timeout_seconds = timeout_seconds
            self.soft_limit_seconds = min(self.soft_limit_seconds, timeout_seconds / 2)
            self.sample_interval_seconds = min(self.sample_interval_seconds, timeout_seconds / 2)
            self.plan.update(hardTimeoutSeconds=self.hard_timeout_seconds,
                             softLimitSeconds=self.soft_limit_seconds,
                             sampleIntervalSeconds=self.sample_interval_seconds)
        self.output_path = Path(output_path) if output_path is not None else None
        self._samples = []
        self._observations = 0
        self._dropped = 0
        self._gap_count = 0
        self._max_gap = 0
        self._scope_change_count = 0
        self._counter_reset_count = 0

    def observe(self, elapsed_seconds, pid, stdout_bytes, stderr_bytes, *,
                cpu_seconds=None, cpu_scope=None, owned_pids=None):
        elapsed_seconds = _number(elapsed_seconds, "ELAPSED")
        for value, name in ((stdout_bytes, "STDOUT_BYTES"), (stderr_bytes, "STDERR_BYTES")):
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                raise ValueError(f"STEP_DIAGNOSTICS_INVALID_{name}")
        if isinstance(pid, bool) or not isinstance(pid, int) or pid <= 0:
            raise ValueError("STEP_DIAGNOSTICS_INVALID_PID")
        owned_pids = [pid] if owned_pids is None else list(owned_pids)
        if (not owned_pids or len(owned_pids) > 64 or pid not in owned_pids
                or any(isinstance(value, bool) or not isinstance(value, int) or value <= 0
                       for value in owned_pids) or len(set(owned_pids)) != len(owned_pids)):
            raise ValueError("STEP_DIAGNOSTICS_INVALID_OWNED_PIDS")
        owned_pids = sorted(owned_pids)
        if cpu_seconds is None:
            if cpu_scope not in (None, "unknown"):
                raise ValueError("STEP_DIAGNOSTICS_INVALID_UNKNOWN_CPU_SCOPE")
            cpu_scope = "unknown"
        else:
            _number(cpu_seconds, "CPU_SECONDS")
            if cpu_scope not in ("owned-process", "owned-tree"):
                raise ValueError("STEP_DIAGNOSTICS_INVALID_CPU_SCOPE")

        previous = self._samples[-1] if self._samples else None
        if previous is not None and elapsed_seconds < previous["elapsedSeconds"]:
            raise ValueError("STEP_DIAGNOSTICS_NON_MONOTONIC_ELAPSED")
        interval = None if previous is None else elapsed_seconds - previous["elapsedSeconds"]
        if interval is not None:
            self._max_gap = max(self._max_gap, interval)
            if interval > self.sample_interval_seconds * 1.5:
                self._gap_count += 1
        elif elapsed_seconds > self.sample_interval_seconds * 1.5:
            self._gap_count += 1
            self._max_gap = elapsed_seconds

        log_delta = None if previous is None else {
            "stdoutBytes": stdout_bytes - previous["stdoutBytes"],
            "stderrBytes": stderr_bytes - previous["stderrBytes"]}
        same_cpu_scope = (previous is not None and previous["cpuScope"] == cpu_scope
                          and previous["ownedPids"] == owned_pids and previous["pid"] == pid)
        cpu_delta = None
        if previous is not None and not same_cpu_scope:
            self._scope_change_count += 1
        if (same_cpu_scope and cpu_seconds is not None
                and previous["cpuSeconds"] is not None):
            difference = cpu_seconds - previous["cpuSeconds"]
            if difference >= 0:
                cpu_delta = difference
            else:
                self._counter_reset_count += 1
        log_changed = log_delta is not None and any(value != 0 for value in log_delta.values())
        if log_changed or (cpu_delta is not None and cpu_delta > 0):
            activity = "active"
        elif cpu_delta == 0 and log_delta is not None and interval > 0:
            activity = "quiet"
        else:
            activity = "unknown"
        sample = {
            "elapsedSeconds": elapsed_seconds, "pid": pid, "ownedPids": owned_pids,
            "intervalSeconds": interval,
            "processSetChanged": previous is not None and previous["ownedPids"] != owned_pids,
            "cpuContinuity": ("first-observation" if previous is None else
                              "scope-changed" if not same_cpu_scope else
                              "unavailable" if cpu_seconds is None or previous["cpuSeconds"] is None else
                              "counter-reset" if cpu_delta is None else "continuous"),
            "stdoutBytes": stdout_bytes, "stderrBytes": stderr_bytes,
            "logSizeDelta": log_delta, "cpuSeconds": cpu_seconds, "cpuScope": cpu_scope,
            "cpuSecondsDelta": cpu_delta, "activity": activity,
            "slow": elapsed_seconds > self.soft_limit_seconds}
        investigation = self._investigation(sample)
        sample["investigationClassification"] = investigation["classification"]
        sample["causeCandidates"] = list(investigation["causeCandidates"])
        self._observations += 1
        self._samples.append(sample)
        if len(self._samples) > self.plan["maxSamples"]:
            self._samples.pop(1)
            self._dropped += 1
        record = self.snapshot()
        if self.output_path is not None:
            temporary = self.output_path.with_name(self.output_path.name + ".tmp")
            temporary.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
            temporary.replace(self.output_path)
        return record

    def _investigation(self, latest):
        """Select bounded, read-only investigation routes from measured evidence."""
        result = {"required": latest is not None and latest["slow"],
                  "classification": "not-required", "certainty": "candidate-only",
                  "classificationPeriod": "latest-observed-interval",
                  "causeCandidates": [], "nextSteps": [], "evidence": None,
                  "automaticExecution": False}
        if not result["required"]:
            return result
        delta = latest["logSizeDelta"]
        interval = latest["intervalSeconds"]
        positive_interval = interval is not None and interval > 0
        cpu_comparable = positive_interval and latest["cpuSecondsDelta"] is not None
        output_grew = delta is not None and any(value > 0 for value in delta.values())
        output_reset = delta is not None and any(value < 0 for value in delta.values())
        candidates = []
        steps = [{"id": "inspect-existing-step-record", "execution": "read-only",
                  "evidenceFields": ["stage", "plan", "samples", "limitations"],
                  "requiresExplicitExecutionBudget": False}]
        if cpu_comparable and latest["cpuSecondsDelta"] > 0:
            candidates.append("cpu-work-or-spin")
            steps.append({"id": "compare-stage-source-and-input-closure", "execution": "read-only",
                          "requiresExplicitExecutionBudget": False})
        if output_grew:
            candidates.append("output-producing-work")
            steps.append({"id": "inspect-existing-stdout-stderr-content", "execution": "read-only",
                          "requiresExplicitExecutionBudget": False})
        if cpu_comparable and latest["cpuSecondsDelta"] == 0 and delta is not None and not output_grew and not output_reset:
            candidates.append("wait-or-block-or-unmeasured-work")
            steps.append({"id": "plan-bounded-wait-investigation", "execution": "plan-only",
                          "requiresExplicitExecutionBudget": True})
        if not cpu_comparable:
            candidates.append("cpu-measurement-unavailable-or-discontinuous")
            steps.append({"id": "inspect-cpu-scope-and-observation-failure", "execution": "read-only",
                          "evidenceFields": ["cpuIdentity", "cpuObservationFailure", "samples"],
                          "requiresExplicitExecutionBudget": False})
        if latest["processSetChanged"]:
            candidates.append("owned-process-set-changed")
        if output_reset:
            candidates.append("log-counter-reset")
        if interval is not None and interval > self.sample_interval_seconds * 1.5:
            candidates.append("sampling-gap")
        result.update(
            classification=("cpu-active" if cpu_comparable and latest["cpuSecondsDelta"] > 0 else
                            "output-active" if output_grew else
                            "quiet-observed-interval" if cpu_comparable and delta is not None and not output_reset else
                            "insufficient-evidence"),
            causeCandidates=candidates, nextSteps=steps,
            evidence={key: latest[key] for key in ("elapsedSeconds", "intervalSeconds", "pid", "ownedPids",
                       "processSetChanged", "cpuScope", "cpuSecondsDelta", "cpuContinuity", "logSizeDelta")})
        result["evidence"]["ownedPids"] = list(latest["ownedPids"])
        result["evidence"]["logSizeDelta"] = None if delta is None else dict(delta)
        return result

    def snapshot(self):
        latest = self._samples[-1] if self._samples else None
        limitations = ["Activity is sampled evidence, not a root-cause diagnosis.",
                       "Log size changes do not measure content or useful progress.",
                       "Unreported child PIDs and CPU are outside the observed scope."]
        if latest is None or latest["cpuScope"] == "unknown":
            limitations.append("CPU activity is unknown; unchanged logs do not prove inactivity.")
        if self._gap_count:
            limitations.append("Sampling gaps prevent continuous activity conclusions.")
        if self._dropped:
            limitations.append("Sample storage budget exhausted; first and newest observations retained.")
        if self._scope_change_count or self._counter_reset_count:
            limitations.append("CPU scope changes or counter resets break delta continuity.")
        return {
            "schemaVersion": 1, "stage": self.plan["stage"], "plan": dict(self.plan),
            "status": "unobserved" if latest is None else "slow" if latest["slow"] else "within-soft-limit",
            "activity": "unknown" if latest is None else latest["activity"],
            "investigation": self._investigation(latest),
            "observedSamples": self._observations, "retainedSamples": len(self._samples),
            "droppedSamples": self._dropped, "storageBudgetExhausted": self._dropped > 0,
            "samplingGapCount": self._gap_count, "maximumObservedGapSeconds": self._max_gap,
            "cpuScopeChangeCount": self._scope_change_count,
            "cpuCounterResetCount": self._counter_reset_count,
            "samples": [dict(sample, ownedPids=list(sample["ownedPids"]),
                             causeCandidates=list(sample["causeCandidates"]),
                             logSizeDelta=None if sample["logSizeDelta"] is None else dict(sample["logSizeDelta"]))
                        for sample in self._samples],
            "limitations": limitations,
            "automaticRetry": False, "automaticProfiling": False,
            "hardTimeoutChanged": self.hard_timeout_seconds != self.declared_hard_timeout_seconds,
            "declaredHardTimeoutSeconds": self.declared_hard_timeout_seconds}
