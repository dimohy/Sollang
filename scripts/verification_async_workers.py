"""Verify real suspend/resume paths for each generic async worker copy."""
import re


def validate_runtime_selection_contract(spec):
    if (not isinstance(spec, dict) or set(spec) != {"fileWorker", "ioCompletion"}
            or any(type(value) is not bool for value in spec.values())
            or spec["fileWorker"] and not spec["ioCompletion"]):
        raise ValueError("ASYNC_RUNTIME_SELECTION_CONTRACT_INVALID")


def validate_runtime_selection(llvm, spec):
    """Check definitions and owned globals, including dormant unwanted workers."""
    validate_runtime_selection_contract(spec)
    llvm = llvm.replace("\r\n", "\n")
    expected = {
        "sollang_file_worker_run": ("function", spec["fileWorker"]),
        "sollang_file_request_head": ("global", spec["fileWorker"]),
        "sollang_file_worker_started": ("global", spec["fileWorker"]),
        "sollang_file_worker_stopping": ("global", spec["fileWorker"]),
        "sollang_io_push_completion": ("function", spec["ioCompletion"]),
        "sollang_io_completion_head": ("global", spec["ioCompletion"]),
    }
    observed = {}
    for name, (kind, present) in expected.items():
        pattern = (r"^define\b[^\n]*@" + re.escape(name) + r"\(" if kind == "function"
                   else r"^@" + re.escape(name) + r"\s*=")
        count = len(re.findall(pattern, llvm, re.M))
        if count != int(present):
            raise ValueError("ASYNC_RUNTIME_SELECTION_MISMATCH:" + name)
        observed[name] = count
    return observed


def validate_worker_contract(spec):
    if (not isinstance(spec, dict)
            or type(spec.get("sourceSymbol")) is not int or spec["sourceSymbol"] < 0
            or type(spec.get("copies")) is not int or spec["copies"] < 1
            or not isinstance(spec.get("resumeStates"), list) or not spec["resumeStates"]
            or any(type(value) is not int or value < 1 for value in spec["resumeStates"])
            or spec["resumeStates"] != sorted(set(spec["resumeStates"]))):
        raise ValueError("ASYNC_WORKER_CONTRACT_INVALID")


def validate_workers(llvm, spec):
    validate_worker_contract(spec)
    pattern = (r"^define i1 @(?P<name>sollang_m\d+_s" + str(spec["sourceSymbol"])
               + r"_g\d+_async_worker)\(ptr %control\) \{\n(?P<body>.*?)^\}")
    workers = list(re.finditer(pattern, llvm.replace("\r\n", "\n"), re.M | re.S))
    if len(workers) != spec["copies"]:
        raise ValueError("ASYNC_WORKER_COPY_COUNT_MISMATCH")
    observed = []
    for worker in workers:
        body = worker["body"]
        switches = re.findall(r"switch i32 %async_resume_state, label %async_state_invalid \[(.*?)\]", body, re.S)
        if len(switches) != 1:
            raise ValueError("ASYNC_WORKER_DISPATCH_MISSING")
        states = [int(value) for value in re.findall(r"i32 (\d+), label %async_resume\d+", switches[0])]
        if states != spec["resumeStates"]:
            raise ValueError("ASYNC_WORKER_RESUME_STATES_MISMATCH:" + worker["name"])
        for state in states:
            if len(re.findall(r"^async_resume" + str(state) + r":$", body, re.M)) != 1:
                raise ValueError("ASYNC_WORKER_RESUME_LABEL_MISSING")
        parks = len(re.findall(r"call void @sollang_task_park_on\(", body))
        if parks != len(states):
            raise ValueError("ASYNC_WORKER_PARK_COUNT_MISMATCH")
        observed.append(dict(name=worker["name"], resumeStates=states, parkCount=parks))
    return observed
