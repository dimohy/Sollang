"""Shared mapped-source lifetime contract for generated diagnostic profiles.

The outer loader retains mapped owners until after the last EmitContext use.
The canonical context factory receives borrowed wrappers, as in production.
This checks the supported generated loader, not arbitrary Sollang lifetimes.
"""

LOADER_TEMPLATE = '''

public profileResolvedFiles paths: [Text; ~] -> Int uses Console, File {
    "prepare-files" -> profileMark
    [file.SourceText; ~] => owners!
    paths -> each path { owners! -> push(path -> file.mapText) }
    [Text; ~] => sources!
    0 => sourceIndex!
    sourceIndex! < (owners! -> len) -> while {
        owners![sourceIndex!] -> sourceDecoding.utf8Text => source
        sources! -> push(source)
        sourceIndex! + 1 => sourceIndex!
    }
    sources! -> analysis.analyzeCheckedTextSources -> when {
        Err(code) { code -> return }
        Ok(value) { value }
    } => parsedPackage
    parsedPackage -> semanticContext.prepareAnalyzedWithStandardLibrarySources(__STDLIB_COUNT__) => prepared
    llvmTarget.windowsX64() => target
    PrepareRequest { sources: sources!, standardLibrarySourceStart: 0, standardLibrarySourceCount: __STDLIB_COUNT__, pointerBitWidth: target.pointerBitWidth, targetArchitecture: target.architecture, cpuDispatchPolicy: target.dispatchPolicy, requiredCpuFeatures: target.requiredFeatures, allowedCpuFeatures: target.allowedFeatures, forbiddenCpuFeatures: target.forbiddenFeatures, supportsComputePool: true, expectedPathStyle: 1 } => request
    prepared -> semanticDiagnostics.firstPreparedExplicitSignatureTypeDiagnostic => signatureDiagnostic
    prepared.package -> semanticDiagnostics.unresolvedMutableLocalReads => mutableNames
    libraryImports.empty() => libraries
    [libraryImports.LibraryFunctionResolution; ~] => libraryCalls
    prepared.package -> libraryImports.callResultTypes(prepared.semantic.types, libraries, libraryCalls) => externalResults
    "resolve-call-context" -> profileMark
    prepared -> expressionTypeIds.resolveCallContextWithExternalResults(externalResults) => resolved
    "resolved-context" -> profileMark
    request -> profileResolvedSnapshot(resolved, libraries, libraryCalls, mutableNames, signatureDiagnostic) => context
    "blocking-diagnostics" -> profileMark
    context -> diagnostics.blockingDiagnosticCount => count
    owners! -> len => ownerCount
    "retained-owners-$ownerCount" -> profileMark
    "complete" -> profileMark
    count
}
'''


def render_loader(standard_library_count):
    if type(standard_library_count) is not int or standard_library_count <= 0:
        raise ValueError("PROFILE_STDLIB_COUNT_INVALID")
    return LOADER_TEMPLATE.replace("__STDLIB_COUNT__", str(standard_library_count))


def render_profile_prefix(canonical):
    # Retain the complete original module. Checked-preparation types and helper
    # functions may follow lowerPreparedIr; slicing at that function silently
    # dropped their declarations when the production module evolved.
    decoder = "import sollang.compiler.syntax.source_decoding as sourceDecoding"
    if decoder not in canonical:
        anchor = "import sys.file as file"
        if canonical.count(anchor) != 1:
            raise ValueError("PROFILE_CANONICAL_FILE_IMPORT_REQUIRED")
        canonical = canonical.replace(anchor, decoder + "\n" + anchor, 1)
    return canonical.rstrip() + "\n"


def validate_loader(profile, standard_library_count):
    marker = "\npublic profileResolvedFiles"
    if profile.count(marker) != 1:
        raise ValueError("PROFILE_OUTER_SOURCE_OWNERS_REQUIRED")
    actual = profile[profile.index(marker):].strip()
    if actual != render_loader(standard_library_count).strip():
        raise ValueError("PROFILE_OUTER_SOURCE_OWNERS_REQUIRED")
