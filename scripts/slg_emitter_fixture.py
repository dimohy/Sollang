"""Render a production emitter probe with typed sources and checked diagnostics.

Keep emitter API and process-exit wiring here instead of reconstructing them in
each fixture. The source program still requires its own C# prerequisite proof.
"""

from slg_fixture_literals import multiline_raw_literal


def emitter_fixture(program: str) -> str:
    if not isinstance(program, str) or not program.strip():
        raise ValueError("SLG_EMITTER_FIXTURE_PROGRAM_REQUIRED")
    return (
        "import sollang.compiler.llvm.text as llvmText\n"
        "import sys.process as process\n\n"
        "main {\n"
        + multiline_raw_literal(program)
        + " => input\n"
        "    [Text; ~] => sources!\n"
        "    sources! -> push(input)\n"
        "    sources! -> llvmText.emitChecked => diagnosticCount\n"
        "    diagnosticCount > 0 -> if { diagnosticCount -> process.exit }\n"
        "}\n"
    )
