"""Render source text inside a standalone Sollang multiline raw literal.

Callers put the returned literal on its own lines before binding it. Inline
opening delimiters cannot establish the indentation contract used here.
"""


def multiline_raw_literal(source: str, indent: int = 4) -> str:
    if not isinstance(source, str):
        raise TypeError("SLG_FIXTURE_SOURCE_REQUIRED")
    if not isinstance(indent, int) or isinstance(indent, bool) or indent < 0:
        raise ValueError("SLG_FIXTURE_INDENT_INVALID")
    if '"""' in source:
        raise ValueError("SLG_FIXTURE_RAW_DELIMITER_IN_SOURCE")
    if "\r" in source.replace("\r\n", ""):
        raise ValueError("SLG_FIXTURE_BARE_CR")
    normalized = source.replace("\r\n", "\n")
    prefix = " " * indent
    lines = normalized.split("\n")
    return "\n".join([prefix + '"""', *(prefix + line for line in lines), prefix + '"""'])
