import { createHash } from "node:crypto";
import { access, readFile, rename, stat, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { benchmarkCases } from "../benchmarks/perf100/cases.mjs";

const root = resolve(import.meta.dirname, "..");
const bin = resolve(root, "artifacts", "perf100", "bin");
const resultDirectory = resolve(root, "artifacts", "perf100");
const sollangCompiler = process.env.SOLLANG_PERF_COMPILER
  ?? resolve(root, "artifacts", "example-tests", "selfhost-stage3-linux");
const warmup = Number.parseInt(process.env.PERF100_WARMUP ?? "2", 10);
const runs = Number.parseInt(process.env.PERF100_RUNS ?? "7", 10);
const filterText = process.env.PERF100_FILTER ?? "";
const idleSeconds = Number.parseInt(process.env.PERF100_IDLE_SECONDS ?? "10", 10);
const idleLimitPercent = Number.parseFloat(process.env.PERF100_IDLE_LIMIT_PERCENT ?? "10");
const caseIdleSeconds = Number.parseInt(process.env.PERF100_CASE_IDLE_SECONDS ?? "2", 10);
const resumeEnabled = (process.env.PERF100_RESUME ?? "1") !== "0";
const filter = filterText === "" ? null : new RegExp(filterText);
const selectedCases = filter === null
  ? benchmarkCases
  : benchmarkCases.filter((entry) => filter.test(entry.id) || filter.test(entry.family));

if (!Number.isInteger(warmup) || warmup < 0 || !Number.isInteger(runs) || runs < 3) {
  throw new Error("PERF100_WARMUP must be >= 0 and PERF100_RUNS must be >= 3");
}
if (!Number.isInteger(idleSeconds) || idleSeconds < 5 || !Number.isFinite(idleLimitPercent)
    || idleLimitPercent <= 0 || idleLimitPercent > 25 || !Number.isInteger(caseIdleSeconds)
    || caseIdleSeconds < 1) {
  throw new Error("idle gate requires PERF100_IDLE_SECONDS >= 5, PERF100_CASE_IDLE_SECONDS >= 1, and 0 < PERF100_IDLE_LIMIT_PERCENT <= 25");
}
if (selectedCases.length === 0) throw new Error(`PERF100_FILTER matched no cases: ${filterText}`);

function parseCpuStat(text) {
  const line = text.split(/\r?\n/).find((value) => value.startsWith("cpu "));
  if (line === undefined) throw new Error("/proc/stat has no aggregate cpu row");
  const fields = line.trim().split(/\s+/).slice(1).map(Number);
  if (fields.length < 8 || fields.some((value) => !Number.isFinite(value))) {
    throw new Error("/proc/stat aggregate cpu row is malformed");
  }
  return { idle: fields[3] + fields[4], total: fields.reduce((sum, value) => sum + value, 0) };
}

async function sampleCpuBusy(seconds) {
  const before = parseCpuStat(await readFile("/proc/stat", "utf8"));
  await new Promise((resolveDelay) => setTimeout(resolveDelay, seconds * 1000));
  const after = parseCpuStat(await readFile("/proc/stat", "utf8"));
  const total = after.total - before.total;
  const idle = after.idle - before.idle;
  if (total <= 0 || idle < 0) throw new Error("host CPU counters did not advance monotonically");
  return ((total - idle) * 100) / total;
}

async function requireIdle(stage, seconds) {
  const busyPercent = await sampleCpuBusy(seconds);
  if (busyPercent > idleLimitPercent) {
    throw new Error(`${stage} refused: host CPU busy ${busyPercent.toFixed(2)}% exceeds ${idleLimitPercent.toFixed(2)}%`);
  }
  return { stage, seconds, busyPercent };
}

const languages = [
  { name: "sollang", executable: resolve(bin, "sollang"), args: (entry) => [entry.familyId, entry.input, entry.seed] },
  { name: "cpp", executable: resolve(bin, "cpp"), args: (entry) => [entry.familyId, entry.input, entry.seed] },
  { name: "rust", executable: resolve(bin, "rust"), args: (entry) => [entry.familyId, entry.input, entry.seed] },
  { name: "csharp-nativeaot", executable: resolve(bin, "csharp-nativeaot", "Perf100"), args: (entry) => [entry.familyId, entry.input, entry.seed] },
  { name: "go", executable: resolve(bin, "go"), args: (entry) => [entry.familyId, entry.input, entry.seed] },
  { name: "java", executable: "/usr/bin/java", artifact: resolve(bin, "java.jar"), args: (entry) => ["-jar", resolve(bin, "java.jar"), entry.familyId, entry.input, entry.seed] },
];

function sameExecutableSet(left, right) {
  return languages.every((language) => left?.[language.name]?.sha256 === right?.[language.name]?.sha256
    && left?.[language.name]?.bytes === right?.[language.name]?.bytes);
}

function invoke(language, entry) {
  const result = spawnSync(language.executable, language.args(entry).map(String), {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0) {
    throw new Error(`${language.name} failed for ${entry.id} (${result.status}):\n${result.stderr}${result.stdout}`);
  }
  return result.stdout;
}

function median(values) {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2 === 0 ? (ordered[middle - 1] + ordered[middle]) / 2 : ordered[middle];
}

function medianAbsoluteDeviation(values) {
  const center = median(values);
  return median(values.map((value) => Math.abs(value - center)));
}

function sampleSummary(values) {
  return {
    medianMs: median(values),
    madMs: medianAbsoluteDeviation(values),
    minMs: Math.min(...values),
    maxMs: Math.max(...values),
  };
}

function peakRss(language, entry) {
  const marker = "PERF100_MAX_RSS_KIB=";
  const result = spawnSync("/usr/bin/time", ["-f", `${marker}%M`, language.executable, ...language.args(entry).map(String)], {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0) {
    throw new Error(`${language.name} peak-RSS probe failed for ${entry.id} (${result.status}):\n${result.stderr}${result.stdout}`);
  }
  const rssLine = result.stderr.split(/\r?\n/).find((line) => line.startsWith(marker));
  const peakRssKiB = Number.parseInt(rssLine?.slice(marker.length) ?? "", 10);
  if (!Number.isInteger(peakRssKiB) || peakRssKiB <= 0) throw new Error(`missing peak RSS for ${language.name} ${entry.id}`);
  return peakRssKiB;
}

async function executableIdentity(language) {
  const artifact = language.artifact ?? language.executable;
  const bytes = await readFile(artifact);
  const info = await stat(artifact);
  return { sha256: createHash("sha256").update(bytes).digest("hex"), bytes: info.size };
}

function toolVersion(command, args) {
  const result = spawnSync(command, args, { cwd: "/tmp", encoding: "utf8" });
  if (result.status !== 0) throw new Error(`failed to identify ${command}: ${result.stderr}`);
  return result.stdout.trim().split(/\r?\n/, 1)[0];
}

await access("/usr/bin/time");
const buildReport = JSON.parse(await readFile(resolve(resultDirectory, "build-report.json"), "utf8"));
if (buildReport.schema !== 1) throw new Error(`unsupported Perf100 build report schema: ${buildReport.schema}`);
const executables = Object.fromEntries(await Promise.all(languages.map(async (language) => [language.name, await executableIdentity(language)])));
const resultStem = filter === null ? "latest" : `latest-filtered-${createHash("sha256").update(filterText).digest("hex").slice(0, 12)}`;
const partial = resolve(resultDirectory, `${resultStem}.partial.json`);
const completed = resolve(resultDirectory, `${resultStem}.json`);
const startupIdle = await requireIdle("Perf100 startup", idleSeconds);
let report = {
  schema: 1,
  startedUtc: new Date().toISOString(),
  machine: {
    cpu: toolVersion("bash", ["-lc", "lscpu | sed -n 's/^Model name:[[:space:]]*//p'"]),
    kernel: toolVersion("uname", ["-srvmo"]),
  },
  toolchains: {
    cpp: toolVersion("g++", ["--version"]),
    rust: toolVersion("bash", ["-lc", "source \"$HOME/.cargo/env\" && rustc --version"]),
    csharpNativeAot: toolVersion("dotnet", ["--version"]),
    go: toolVersion("/usr/local/go/bin/go", ["version"]),
    java: toolVersion("java", ["--version"]),
    sollang: toolVersion(sollangCompiler, ["--version"]),
  },
  warmup,
  runs,
  measurementModel: "one fresh process per sample; warmups prime host caches but do not preserve language-runtime state",
  filter: filterText,
  idleGate: { limitPercent: idleLimitPercent, startup: startupIdle, sessions: [startupIdle], cases: [] },
  requiredSollangRank: 3,
  executables,
  build: buildReport,
  cases: [],
};

let startCaseIndex = 0;
if (resumeEnabled) {
  try {
    const previous = JSON.parse(await readFile(partial, "utf8"));
    const prefixMatches = previous.cases?.every((entry, index) => entry.id === selectedCases[index]?.id) ?? false;
    const compatible = previous.schema === 1
      && previous.warmup === warmup
      && previous.runs === runs
      && previous.filter === filterText
      && previous.idleGate?.limitPercent === idleLimitPercent
      && previous.requiredSollangRank === 3
      && prefixMatches
      && previous.cases.length < selectedCases.length
      && sameExecutableSet(previous.executables, executables)
      && JSON.stringify(previous.build) === JSON.stringify(buildReport);
    if (!compatible) {
      throw new Error(`existing partial report is incompatible; inspect it or rerun with PERF100_RESUME=0: ${partial}`);
    }
    report = previous;
    report.idleGate.sessions ??= [report.idleGate.startup];
    report.idleGate.sessions.push(startupIdle);
    startCaseIndex = report.cases.length;
    process.stdout.write(`Resuming Perf100 at ${selectedCases[startCaseIndex].id} after ${startCaseIndex} completed cases\n`);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}

for (let caseIndex = startCaseIndex; caseIndex < selectedCases.length; caseIndex += 1) {
  const entry = selectedCases[caseIndex];
  const caseIdle = await requireIdle(`Perf100 case ${entry.id}`, caseIdleSeconds);
  report.idleGate.cases.push({ caseId: entry.id, ...caseIdle });
  const outputs = languages.map((language) => ({ language: language.name, output: invoke(language, entry) }));
  const expected = outputs[0].output;
  for (const output of outputs) {
    if (output.output !== expected) {
      throw new Error(`checksum mismatch for ${entry.id}: sollang=${JSON.stringify(expected)}, ${output.language}=${JSON.stringify(output.output)}`);
    }
  }

  for (let iteration = 0; iteration < warmup; iteration += 1) {
    for (let offset = 0; offset < languages.length; offset += 1) {
      invoke(languages[(caseIndex + iteration + offset) % languages.length], entry);
    }
  }

  const samples = Object.fromEntries(languages.map((language) => [language.name, []]));
  for (let iteration = 0; iteration < runs; iteration += 1) {
    for (let offset = 0; offset < languages.length; offset += 1) {
      const language = languages[(caseIndex + iteration + offset) % languages.length];
      const started = process.hrtime.bigint();
      invoke(language, entry);
      const elapsed = Number(process.hrtime.bigint() - started) / 1_000_000;
      samples[language.name].push(elapsed);
    }
  }

  const statistics = Object.fromEntries(languages.map((language) => [language.name, sampleSummary(samples[language.name])]));
  const medians = Object.fromEntries(languages.map((language) => [language.name, statistics[language.name].medianMs]));
  const peakRssKiB = Object.fromEntries(languages.map((language) => [language.name, peakRss(language, entry)]));
  const ranking = Object.entries(medians).sort((left, right) => left[1] - right[1]).map(([language], index) => ({ rank: index + 1, language, medianMs: medians[language] }));
  const sollangRank = ranking.find((item) => item.language === "sollang").rank;
  report.cases.push({ ...entry, checksum: expected.trim(), samplesMs: samples, statistics, peakRssKiB, ranking, sollangRank, pass: sollangRank <= 3 });
  await writeFile(partial, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  process.stdout.write(`[${caseIndex + 1}/${selectedCases.length}] ${entry.id} ${entry.family}: Sollang #${sollangRank} ${medians.sollang.toFixed(3)}ms\n`);
}

report.completedUtc = new Date().toISOString();
report.summary = {
  passing: report.cases.filter((entry) => entry.pass).length,
  firstPlace: report.cases.filter((entry) => entry.sollangRank === 1).length,
  failing: report.cases.filter((entry) => !entry.pass).length,
  total: report.cases.length,
};
await writeFile(partial, `${JSON.stringify(report, null, 2)}\n`, "utf8");
await rename(partial, completed);
process.stdout.write(`Perf100: ${report.summary.passing}/${report.summary.total} top-three, ${report.summary.firstPlace}/${report.summary.total} first-place\n`);
if (report.summary.failing !== 0) process.exitCode = 1;
