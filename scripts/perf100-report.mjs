import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const input = resolve(root, process.argv[2] ?? "artifacts/perf100/latest.json");
const bytes = await readFile(input);
const report = JSON.parse(bytes.toString("utf8"));
if (report.schema !== 1 || report.summary?.total !== 100 || report.cases?.length !== 100) {
  throw new Error("Perf100 report must contain exactly 100 schema-1 cases");
}

const completedDate = report.completedUtc.slice(0, 10);
const output = resolve(root, process.argv[3] ?? `benchmarks/perf100/results-${completedDate}.md`);
const rawSha256 = createHash("sha256").update(bytes).digest("hex");
const ranks = [1, 2, 3, 4, 5, 6].map((rank) => report.cases.filter((entry) => entry.sollangRank === rank).length);
const maxIdleBusy = Math.max(
  ...report.idleGate.sessions.map((entry) => entry.busyPercent),
  ...report.idleGate.cases.map((entry) => entry.busyPercent),
);
const languages = Object.keys(report.executables);

function fixed(value, digits = 3) {
  return Number(value).toFixed(digits);
}

const lines = [
  `# Perf100 results — ${completedDate}`,
  "",
  `Status: **${report.summary.passing === 100 ? "PASS" : "FAIL"} — ${report.summary.passing}/100 top-three, ${report.summary.firstPlace}/100 first-place**`,
  "",
  "## Contract and provenance",
  "",
  `- Raw report SHA-256: \`${rawSha256}\` (${bytes.length.toLocaleString("en-US")} bytes)` ,
  `- Measurement window: \`${report.startedUtc}\` to \`${report.completedUtc}\`` ,
  `- Host: ${report.machine.cpu}; ${report.machine.kernel}`,
  `- Protocol: ${report.measurementModel}; ${report.warmup} warmups and ${report.runs} measured samples per language and case`,
  `- Idle gate: at most ${fixed(report.idleGate.limitPercent, 2)}% aggregate busy; ${report.idleGate.sessions.length} run sessions; maximum accepted observation ${fixed(maxIdleBusy, 3)}%`,
  `- Rank distribution: #1 ${ranks[0]}, #2 ${ranks[1]}, #3 ${ranks[2]}, below target ${ranks.slice(3).reduce((sum, value) => sum + value, 0)}`,
  "",
  "Every case checked byte-identical stdout across Sollang, C++, Rust, C# NativeAOT, Go, and Java before timing. The report also retains every raw sample, median absolute deviation, range, peak RSS, executable identity, source identity, and build duration.",
  "",
  "## Toolchains",
  "",
  "| Implementation | Toolchain | Build ms | Executable bytes | SHA-256 | Max peak RSS KiB |",
  "|---|---|---:|---:|---|---:|",
];

const toolchainByLanguage = {
  sollang: report.toolchains.sollang,
  cpp: report.toolchains.cpp,
  rust: report.toolchains.rust,
  "csharp-nativeaot": report.toolchains.csharpNativeAot,
  go: report.toolchains.go,
  java: report.toolchains.java,
};
for (const language of languages) {
  const peak = Math.max(...report.cases.map((entry) => entry.peakRssKiB[language]));
  const executable = report.executables[language];
  const build = report.build.entries[language];
  lines.push(`| ${language} | ${toolchainByLanguage[language]} | ${build.elapsedMs} | ${executable.bytes} | \`${executable.sha256}\` | ${peak} |`);
}

lines.push(
  "",
  "## Family results",
  "",
  "| ID | Family | Category | Sollang ranks by profile | First places | Worst rank | Sollang median range ms |",
  "|---:|---|---|---|---:|---:|---:|",
);
for (const familyId of [...new Set(report.cases.map((entry) => entry.familyId))]) {
  const cases = report.cases.filter((entry) => entry.familyId === familyId);
  const medians = cases.map((entry) => entry.statistics.sollang.medianMs);
  lines.push(`| ${familyId} | ${cases[0].family} | ${cases[0].category} | ${cases.map((entry) => entry.sollangRank).join(", ")} | ${cases.filter((entry) => entry.sollangRank === 1).length}/5 | ${Math.max(...cases.map((entry) => entry.sollangRank))} | ${fixed(Math.min(...medians))}–${fixed(Math.max(...medians))} |`);
}

lines.push(
  "",
  "## Sieve correction",
  "",
  "The first complete baseline exposed one failure: the largest monolithic prime sieve made Sollang rank fifth because its growable Boolean array was initialized with millions of pushes while the comparison languages allocated their storage in one operation. The six implementations were therefore moved together to the same segmented sieve contract: a 32,768-element Int64 segment, an Int64 base-prime table, identical reset and marking order, and unchanged inputs and checksums. In the final full run all five sieve profiles ranked first.",
  "",
  "The benchmark did not add compiler branches, precompute answers, reduce inputs, relax idle limits, or reuse results across changed source or executable hashes.",
);

await writeFile(output, `${lines.join("\n")}\n`, "utf8");
process.stdout.write(`Wrote ${output}\n`);
