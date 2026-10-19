"""Read bounded, depth-zero call traces without claiming root completion."""
from __future__ import annotations


def summarize(plan: dict, trace: str) -> dict:
    root = plan['root']
    if plan['depth'] != 0 or plan['owners'] != [root]:
        raise ValueError('SINGLE_OWNER_TRACE_SCOPE_REQUIRED')
    allowed = {row['label'] for row in plan['markers']}
    lines = trace.splitlines(keepends=True)
    complete = [line.rstrip('\r\n') for line in lines if line.endswith('\n')]
    pending = None
    returned = []
    entered = False
    for label in complete:
        if label not in allowed:
            raise ValueError('SINGLE_OWNER_TRACE_UNKNOWN_MARKER')
        if label == 'enter:' + root:
            if entered or pending is not None:
                raise ValueError('SINGLE_OWNER_TRACE_REENTRY')
            entered = True
            continue
        if not entered:
            raise ValueError('SINGLE_OWNER_TRACE_ENTRY_REQUIRED')
        kind, boundary = label.split(':', 1)
        owner, callee = boundary.split('->', 1)
        if owner != root:
            raise ValueError('SINGLE_OWNER_TRACE_FOREIGN_OWNER')
        if kind == 'before' and pending is None:
            pending = callee
        elif kind == 'after' and pending == callee:
            returned.append(callee)
            pending = None
        else:
            raise ValueError('SINGLE_OWNER_TRACE_UNMATCHED_BOUNDARY')
    exhausted = len(complete) >= plan['maximumRecords']
    return dict(scope='diagnostic-only-not-root-completion',
                records=len(complete), rootEntered=entered,
                returnedCalls=returned, pendingCall=pending,
                traceBudgetExhausted=exhausted,
                pendingCallConclusive=entered and pending is not None and not exhausted,
                ignoredPartialLine=bool(lines and not lines[-1].endswith('\n')))
