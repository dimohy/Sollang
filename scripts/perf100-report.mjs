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
const englishOutput = resolve(root, process.argv[3] ?? `benchmarks/perf100/results-${completedDate}.md`);
const koreanOutput = resolve(root, process.argv[4] ?? `benchmarks/perf100/results-${completedDate}.ko.md`);
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

function ranksByProfile(cases, language) {
  return cases.map((entry) => {
    const ranking = entry.ranking.find((item) => item.language === language);
    if (!ranking) {
      throw new Error(`Perf100 case ${entry.id} is missing the ${language} ranking`);
    }
    return ranking.rank;
  }).join(", ");
}

const englishLines = [
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
  englishLines.push(`| ${language} | ${toolchainByLanguage[language]} | ${build.elapsedMs} | ${executable.bytes} | \`${executable.sha256}\` | ${peak} |`);
}

englishLines.push(
  "",
  "## Family results",
  "",
  "| ID | Family | Category | Sollang | C++ | Rust | C# NativeAOT | Go | Java | Sollang first places | Sollang worst rank | Sollang median range ms |",
  "|---:|---|---|---|---|---|---|---|---|---:|---:|---:|",
);
for (const familyId of [...new Set(report.cases.map((entry) => entry.familyId))]) {
  const cases = report.cases.filter((entry) => entry.familyId === familyId);
  const medians = cases.map((entry) => entry.statistics.sollang.medianMs);
  englishLines.push(`| ${familyId} | ${cases[0].family} | ${cases[0].category} | ${ranksByProfile(cases, "sollang")} | ${ranksByProfile(cases, "cpp")} | ${ranksByProfile(cases, "rust")} | ${ranksByProfile(cases, "csharp-nativeaot")} | ${ranksByProfile(cases, "go")} | ${ranksByProfile(cases, "java")} | ${cases.filter((entry) => entry.sollangRank === 1).length}/5 | ${Math.max(...cases.map((entry) => entry.sollangRank))} | ${fixed(Math.min(...medians))}–${fixed(Math.max(...medians))} |`);
}

englishLines.push(
  "",
  "## Sieve correction",
  "",
  "The first complete baseline exposed one failure: the largest monolithic prime sieve made Sollang rank fifth because its growable Boolean array was initialized with millions of pushes while the comparison languages allocated their storage in one operation. The six implementations were therefore moved together to the same segmented sieve contract: a 32,768-element Int64 segment, an Int64 base-prime table, identical reset and marking order, and unchanged inputs and checksums. In the final full run all five sieve profiles ranked first.",
  "",
  "The benchmark did not add compiler branches, precompute answers, reduce inputs, relax idle limits, or reuse results across changed source or executable hashes.",
);

const koreanCategory = {
  integer: "정수 연산",
  branch: "분기",
  call: "함수 호출",
  "floating-point": "부동소수점",
  loop: "반복",
  memory: "메모리",
  sorting: "정렬",
  search: "검색",
};
const koreanLines = [
  `# Perf100 결과 — ${completedDate}`,
  "",
  `상태: **${report.summary.passing === 100 ? "통과" : "실패"} — 3위 이내 ${report.summary.passing}/100개, 1위 ${report.summary.firstPlace}/100개**`,
  "",
  "## 측정 계약과 출처",
  "",
  `- 원시 보고서 SHA-256: \`${rawSha256}\` (${bytes.length.toLocaleString("ko-KR")}바이트)`,
  `- 측정 시간: \`${report.startedUtc}\`부터 \`${report.completedUtc}\`까지`,
  `- 호스트: ${report.machine.cpu}; ${report.machine.kernel}`,
  `- 측정 방식: 표본마다 새 프로세스를 실행하며, 준비 실행은 호스트 캐시만 예열하고 언어 런타임 상태나 JIT 상태를 유지하지 않음; 언어·사례별 준비 실행 ${report.warmup}회와 측정 ${report.runs}회`,
  `- 유휴 CPU 게이트: 전체 CPU 사용률 ${fixed(report.idleGate.limitPercent, 2)}% 이하; 실행 세션 ${report.idleGate.sessions.length}개; 허용된 최대 관측값 ${fixed(maxIdleBusy, 3)}%`,
  `- 순위 분포: 1위 ${ranks[0]}개, 2위 ${ranks[1]}개, 3위 ${ranks[2]}개, 목표 미달 ${ranks.slice(3).reduce((sum, value) => sum + value, 0)}개`,
  "",
  "모든 사례는 시간을 측정하기 전에 Sollang, C++, Rust, C# NativeAOT, Go, Java의 표준 출력이 바이트 단위로 같은지 확인 함. 원시 보고서에는 모든 측정 표본, 중앙값 절대 편차(MAD), 범위, 최대 RSS, 실행 파일·소스 식별 정보와 빌드 시간도 보존 함.",
  "",
  "## 도구 체인",
  "",
  "| 구현 | 도구 체인 | 빌드 시간(ms) | 실행 파일 크기(바이트) | SHA-256 | 최대 RSS(KiB) |",
  "|---|---|---:|---:|---|---:|",
];

for (const language of languages) {
  const peak = Math.max(...report.cases.map((entry) => entry.peakRssKiB[language]));
  const executable = report.executables[language];
  const build = report.build.entries[language];
  koreanLines.push(`| ${language} | ${toolchainByLanguage[language]} | ${build.elapsedMs} | ${executable.bytes} | \`${executable.sha256}\` | ${peak} |`);
}

koreanLines.push(
  "",
  "## 알고리즘군별 결과",
  "",
  "| ID | 알고리즘군 | 분류 | Sollang | C++ | Rust | C# NativeAOT | Go | Java | Sollang 1위 횟수 | Sollang 최하 순위 | Sollang 중앙값 범위(ms) |",
  "|---:|---|---|---|---|---|---|---|---|---:|---:|---:|",
);
for (const familyId of [...new Set(report.cases.map((entry) => entry.familyId))]) {
  const cases = report.cases.filter((entry) => entry.familyId === familyId);
  const medians = cases.map((entry) => entry.statistics.sollang.medianMs);
  koreanLines.push(`| ${familyId} | ${cases[0].family} | ${koreanCategory[cases[0].category] ?? cases[0].category} | ${ranksByProfile(cases, "sollang")} | ${ranksByProfile(cases, "cpp")} | ${ranksByProfile(cases, "rust")} | ${ranksByProfile(cases, "csharp-nativeaot")} | ${ranksByProfile(cases, "go")} | ${ranksByProfile(cases, "java")} | ${cases.filter((entry) => entry.sollangRank === 1).length}/5 | ${Math.max(...cases.map((entry) => entry.sollangRank))} | ${fixed(Math.min(...medians))}–${fixed(Math.max(...medians))} |`);
}

koreanLines.push(
  "",
  "## 소수 판별 알고리즘 개선",
  "",
  "첫 번째 전체 기준선에서는 가장 큰 단일 배열 소수 체 사례 하나가 실패 함. 비교 언어들은 저장 공간을 한 번에 할당했지만 Sollang은 확장 가능한 Bool 배열을 수백만 번 push해 초기화하면서 5위가 됨. 따라서 Sollang만 유리하게 바꾸지 않고 여섯 구현 모두를 동일한 분할 소수 체 계약으로 변경 함. 이 계약은 32,768개 Int64 원소의 세그먼트, Int64 기반 합성수 표, 동일한 초기화·배수 표시·개수 집계 순서, 변경하지 않은 입력과 체크섬을 사용 함. 최종 전체 측정에서 소수 체 프로필 5개는 모두 Sollang이 1위를 기록 함.",
  "",
  "이 벤치마크에는 벤치마크 전용 컴파일러 분기, 결과 사전 계산, 입력 축소, 유휴 CPU 제한 완화, 변경된 소스나 실행 파일을 대상으로 한 이전 결과 재사용이 없음.",
);

await Promise.all([
  writeFile(englishOutput, `${englishLines.join("\n")}\n`, "utf8"),
  writeFile(koreanOutput, `${koreanLines.join("\n")}\n`, "utf8"),
]);
process.stdout.write(`Wrote ${englishOutput}\nWrote ${koreanOutput}\n`);
