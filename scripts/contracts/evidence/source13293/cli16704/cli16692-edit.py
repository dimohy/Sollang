from pathlib import Path
import textwrap,json,hashlib,datetime
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';folder=b/'cli16692-candidate';folder.mkdir(exist_ok=False);original=(root/'selfhost/cli_sources.slg').read_text(encoding='utf-8-sig');start=original.index('public loadForTarget ');end=original.index('\npublic load selectedRoot:',start);old=original[start:end];loopstart=old.index('    (stack! -> len) > 0 -> while {');outputstart=old.index('    [path.Path; ~] => sources!');walk=old[loopstart:outputstart];needle='''                            states![existing!] == 1 -> if {
                                units! -> moduleCycle(stack!, existing!, diagnosticStorage) => diagnostic
                                SourceSet { status: 6, diagnostic: diagnostic, sources: [path.Path; ~], owners: [Int; ~] } -> return
                            }
''';assert needle in walk;walk=walk.replace(needle,needle+'''                            states![existing!] == 0 -> if {
                                1 => states![existing!]
                                stack! -> push(existing!)
                            }
''');output=old[outputstart:old.rfind('\n}')]
helper='''# Project and explicit-file entry points share the same import walk.
# Explicit roots remain in their supplied order; imports append once.
resolveSourceSet initialUnits: move [SourceUnit; ~], packages: ref [PackageSource; ~], names: ref [path.Path; ~], initialRoot: Int, target: Text, style: path.Style, diagnosticStorage: mut Arena -> SourceSet uses File {
    initialUnits => units!
    units! -> len => initialCount
    [Int; ~] => states!
    [Int; ~] => cursors!
    [Int; ~] => stack!
    0 => initialIndex!
    initialIndex! < initialCount -> while {
        states! -> push(0)
        cursors! -> push(0)
        initialIndex! + 1 => initialIndex!
    }
    0 => rootOrder!
    rootOrder! < initialCount -> while {
        rootOrder! == 0 -> if { initialRoot } else {
            rootOrder! <= initialRoot -> if { rootOrder! - 1 } else { rootOrder! }
        } => rootIndex
        states![rootIndex] == 0 -> if {
            1 => states![rootIndex]
            stack! -> push(rootIndex)
'''+textwrap.indent(walk,'        ')+'''        }
        rootOrder! + 1 => rootOrder!
    }
'''+output+'\n}\n\n'
project=old[:old.index('    [1,; ~] => states!')]+'''    units! -> resolveSourceSet(packages!, names, 0, target, style, diagnosticStorage)
}
'''
standalone='''# Standalone source files have one local package context and no declared
# project dependencies. No project manifest is manufactured or discovered.
public loadFilesForTarget roots: ref [Text; ~], target: Text, style: path.Style, diagnosticStorage: mut Arena -> SourceSet uses File {
    (roots -> len) == 0 -> if {
        SourceSet { status: 8, diagnostic: "source file list is empty", sources: [path.Path; ~], owners: [Int; ~] } -> return
    }
    [path.Path; ~] => names!
    names! -> push(path.fromText("", style))
    [SourceUnit; ~] => units!
    0 => rootIndex!
    rootIndex! < (roots -> len) -> while {
        roots[rootIndex!] -> path.fromText(style) => location
        location -> pathText => locationText
        false => existing!
        0 => unitIndex!
        unitIndex! < (units! -> len) -> while {
            units![unitIndex!].location -> pathText -> pathIdentity.equalsOrdinalIgnoreCase(locationText)
                -> if { true => existing! }
            unitIndex! + 1 => unitIndex!
        }
        not existing! -> if {
            location -> readSource(0, "", false, names!, style, target) => unit
            unit.status != 0 -> if {
                unit -> sourceDiagnostic("", names!, target, diagnosticStorage) => diagnostic
                SourceSet { status: unit.status, diagnostic: diagnostic, sources: [path.Path; ~], owners: [Int; ~] } -> return
            }
            units! -> push(unit)
        }
        rootIndex! + 1 => rootIndex!
    }
    0 => entryCount!
    0 => entryIndex!
    0 => unitIndex!
    unitIndex! < (units! -> len) -> while {
        units![unitIndex!].hasEntry -> if {
            entryCount! + 1 => entryCount!
            unitIndex! => entryIndex!
        }
        unitIndex! + 1 => unitIndex!
    }
    entryCount! > 1 -> if {
        SourceSet { status: 8, diagnostic: "multiple source files contain executable top-level statements; exactly one root file may define the program entry point", sources: [path.Path; ~], owners: [Int; ~] } -> return
    }
    units![entryIndex!].location -> pathText => selectedRoot
    [PackageSource; ~] => packages!
    packages! -> push(PackageSource {
        root: path.fromText(selectedRoot, style),
        sourceRoot: path.fromText(selectedRoot -> directoryOf, style),
        dependencies: [Int; ~]
    })
    units! -> resolveSourceSet(packages!, names!, entryIndex!, target, style, diagnosticStorage)
}
'''
result=original[:start]+helper+project+'\n'+standalone+original[end:];(folder/'cli_sources.slg').write_bytes(result.encode())
driver=(root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg').read_text(encoding='utf-8-sig');marker='''    Arena(0) => outputStorage!
    (outputOption! -> len) > 0 -> if {''';begin=driver.index('runNativeCli ');tail=driver.index(marker,begin);stop=driver.index('\n}',tail);section=driver[tail:stop];assert section.count('sources! -> executeNativeBuild(')==2
addition='''    hostTarget == 0 -> if { path.Style.Windows } else { path.Style.Posix } => standaloneStyle
    Arena(0) => standaloneStorage!
    sources! -> cliSources.loadFilesForTarget(target! -> nativeTargetName, standaloneStyle, standaloneStorage!) => standaloneSources
    standaloneSources.status != 0 -> if {
        "sollang: $(standaloneSources.diagnostic)" -> runtime.eprintln
        1 -> return
    }
    [Text; ~] => expandedSources!
    0 => standaloneSourceIndex!
    standaloneSourceIndex! < (standaloneSources.sources -> len) -> while {
        standaloneSources.sources[standaloneSourceIndex!] -> pathText => sourcePath
        expandedSources! -> push(sourcePath)
        standaloneSourceIndex! + 1 => standaloneSourceIndex!
    }
''';section=section.replace('sources! -> executeNativeBuild(','expandedSources! -> executeNativeBuild(');(folder/'selfhost-sollangc-driver.slg').write_bytes((driver[:tail]+addition+section+driver[stop:]).encode())
record={'schemaVersion':1,'status':'private-source-edited-after-CSharp9;not-integrated','observedAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before':{'selfhost/cli_sources.slg':hashlib.sha256(original.encode()).hexdigest().upper(),'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg':hashlib.sha256(driver.encode()).hexdigest().upper()},'reference9':['cli16683-managed7/result.json','cli16687-managed2/result.json'],'sourceComparison':'scripts/contracts/evidence/source13293/cli-import16674/source-comparison.json','scope':'Factor the existing project import DFS into one implementation. Standalone explicit roots get an empty local package name, preserve input order, select executable root and keep duplicate namespace providers for semantic checks. Existing project dependency checks and diagnostics unchanged.','unverified':['Current private CSharp semantic validation','Bounded actual SLG loader behavior','Retained project paths','Mixed relative/absolute path identity remains a separate path-normalization concern; no claim of complete path/platform parity.','New general Native behavior'],'claimsGoalComplete':False};(folder/'change.json').write_bytes((json.dumps(record,indent=2)+'\n').encode());print('private C741 source candidate prepared; main source inputs unchanged')
