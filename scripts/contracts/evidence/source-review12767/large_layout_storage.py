"""Input-specific storage budget for the metadata-only C711 witnesses."""
import re


def observe(text):
    markers = ("268435456", "536870912", "16106127")
    declarations = {line.split(" = ")[0].strip(): line for line in text.splitlines()
                    if line.startswith("%") and " = type " in line}
    large = {name for name, line in declarations.items() if any(value in line for value in markers)}

    def references(line):
        return any(re.search(re.escape(name) + r"(?![A-Za-z0-9_])", line) for name in large)

    while True:
        expanded = large | {name for name, line in declarations.items() if references(line)}
        if expanded == large:
            break
        large = expanded
    for line in text.splitlines():
        allocation = "alloca " in line or "@malloc(" in line or (
            line.startswith("@") and re.search(r"\bglobal\b", line))
        if allocation and (references(line) or any(value in line for value in markers)):
            raise ValueError("UNEXPECTED_LARGE_STORAGE_INSTANCE " + line)
    return {"largeStorageInstanceAbsent": True, "metadataOnlyLargeTypes": sorted(large)}


def helper_declarations(text):
    declarations = {}
    for marker in ("struct DictionaryEntryLayout", "dictionaryEntryLayout keySize:",
                   "struct BoundedDictionaryLayout", "boundedDictionaryLayout capacity:"):
        starts = list(re.finditer(r"(?m)^" + re.escape(marker), text))
        if len(starts) != 1:
            raise ValueError("LAYOUT_DECLARATION_NOT_UNIQUE " + marker)
        start = starts[0].start()
        end = text.index("{", start) + 1
        depth = 1
        while depth:
            depth += (text[end] == "{") - (text[end] == "}")
            end += 1
        declarations[marker] = text[start:end]
    return declarations


def verify_helper_source(production, fixture):
    actual, copied = helper_declarations(production), helper_declarations(fixture)
    if actual != copied:
        raise ValueError("LAYOUT_HELPER_FIXTURE_DIFFERS_FROM_PRODUCTION")
    return True
