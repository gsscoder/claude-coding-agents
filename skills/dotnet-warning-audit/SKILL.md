---
name: "dotnet-warning-audit"
description: |
  Compiles a .NET solution or project and reports every build warning grouped by severity, with a
  suppression inventory and per-project totals — C#, F#, and VB projects alike
  Not for fixing warnings, editing suppression settings, or judging runtime behavior — report only
argument-hint: "[solution-or-project-path]"
allowed-tools: Bash Read Grep Glob
model: inherit
disable-model-invocation: true
---

Compile a .NET target and report every warning it emits, grouped by severity, with the suppressions that hide others. Report only what a build you actually ran and observed produced — never a warning inferred from source inspection alone

Target: `$ARGUMENTS` when provided, otherwise resolve per Step 1

## Methodology
### Step 1 — Discovery
Locate the target: the path in `$ARGUMENTS` if given, else the single `.sln`/`.slnx` at repo root, else every `.csproj`/`.fsproj`/`.vbproj` not under `bin/` or `obj/`. Ambiguous root with several solutions and no argument: stop and list them rather than guessing

Read before building, since these change what the build emits:
- `TreatWarningsAsErrors`, `WarningLevel`, `AnalysisLevel`, `AnalysisMode`, `EnableNETAnalyzers`, `Nullable`, `NoWarn` in each project file
- the same properties in `Directory.Build.props` and `Directory.Build.targets` — they apply to every project beneath them
- `TargetFramework` vs `TargetFrameworks` per project — Step 3 dedups a multi-targeted repeat

### Step 2 — Build
Incremental build is the primary failure mode of this audit: an up-to-date project is skipped and emits no warnings, producing a silent undercount. Always force a full compile

Run `dotnet build <target> -c Debug --no-incremental --nologo -v n`, redirecting stdout and stderr to a log file under the system temp directory. Do not pass `-warnaserror`. Do not pass `-p:NoWarn=` or otherwise widen suppression — audit the configuration as it is

Two cases to handle before parsing:
- `TreatWarningsAsErrors` is enabled anywhere: those warnings surface as errors and the build fails. Record which projects have it on, then re-run with `-p:TreatWarningsAsErrors=false` to obtain the full inventory, and report the affected diagnostics at their true severity rather than as errors
- the build fails on genuine compile errors: projects downstream of the failure never compile, so the inventory is partial. Report the errors, mark the audit partial, name the projects that did not build, and continue with what did

Restore emits its own diagnostics (`NU*`) that a build with a warm `obj/` will not repeat. Confirm restore ran in this invocation; if it was skipped, run `dotnet restore <target>` separately and merge its warnings into the inventory

### Step 3 — Collect
Parse MSBuild diagnostic lines in their standard shape, which is identical across C#, F#, and VB:
`<path>(<line>,<col>): warning <CODE>: <message> [<project>]`

- deduplicate a warning repeated across target frameworks by `(path, line, col, code)`, and record how many frameworks produced it
- keep per-project attribution — the trailing `[<project>]` is the reliable source, not the file path
- never merge distinct codes that share a message, and never merge distinct sites that share a code

### Step 4 — Classify
Assign each code to one tier. The families below are anchors, not an exhaustive map: classify an unfamiliar code by what its message describes and mark it `(inferred)`

- CRITICAL — probable runtime failure, data loss, or a known vulnerability: nullable dereference and uninitialized non-nullable state (`CS8600`, `CS8602`, `CS8603`, `CS8604`, `CS8618`), fire-and-forget async (`CS4014`), undisposed resources (`CA2000`), vulnerable packages (`NU1901`-`NU1904`)
- HIGH — likely defect: unreachable code (`CS0162`), field never assigned (`CS0649`), async method without await (`CS1998`), ignored return value (`CA1806`), reserved exception types (`CA2201`), assembly version conflicts (`MSB3277`)
- MEDIUM — API lifecycle and compatibility: obsolete API use (`CS0612`, `CS0618`), framework obsoletions (`SYSLIB*`), platform compatibility (`CA1416`), restore fallbacks and downgrades (`NU1603`, `NU1701`)
- LOW — style and maintainability: unused local (`CS0168`, `CS0219`), missing XML doc (`CS1591`), analyzer style and naming rules (`IDE*`, `SA*`, `CA17xx`)

A vulnerable-package warning is CRITICAL regardless of the severity word in its own message

### Step 5 — Suppression inventory
A warning count means little without what is hidden. Search the target's projects for:
- `NoWarn` entries in project files, `Directory.Build.props`, and `Directory.Build.targets`
- `#pragma warning disable` in source — record whether a matching `restore` exists, since a file-wide disable is broader than it usually looks
- `.editorconfig` rules set to `none` or `silent`
- `[SuppressMessage]` attributes and `GlobalSuppressions.cs` entries

Report each suppressed code with its location and count. A suppression carrying no justification — no `Justification` argument, no adjacent comment — is itself a finding

### Step 6 — Report
Produce the Output Format below. Include tiers with a zero count. List at most 5 occurrence sites per code with a count when more exist

## Output Format
```
WARNING AUDIT — <n> warnings · <s> suppressions · <b>/<t> projects built
Target      <resolved solution or project>
Build       full rebuild, <complete | partial: <n> projects did not compile>
Config      TreatWarningsAsErrors: <projects | none> · AnalysisLevel: <value | default> · Nullable: <state>

SEVERITY
  CRITICAL  <n>
  HIGH      <n>
  MEDIUM    <n>
  LOW       <n>

CRITICAL — <n>
  <CODE> × <n> — <what the diagnostic means>  [(inferred) when unmapped]
    <file>:<line>  <project>  [<n> TFMs when multi-targeted]
    ... up to 5, then "+<n> more"

HIGH / MEDIUM / LOW — same shape

SUPPRESSIONS — <s>
  <CODE> — <NoWarn in <file> | #pragma at <file>:<line> | editorconfig <rule> = none> × <n>  <justified | unjustified>

PROJECTS
  <project>  <n> warnings  TWAE:<on|off>
```
Zero warnings across a complete build: state `No warnings emitted` and report only the Config, SUPPRESSIONS, and PROJECTS sections — a clean build with heavy suppression is the finding

## Hard Limits
- Do not modify source, project files, `.editorconfig`, or suppression settings, or propose an inline fix for any warning found — this skill reports, it does not fix; hand remediation to an implementation agent
- Do not report a warning without a build that emitted it — no inference from reading source
- Do not run an incremental build; an up-to-date project silently reports nothing
- Do not pass `-warnaserror`, or add or widen any suppression flag, to shape the result
- Do not report PASS-equivalent completeness when a project failed to compile — mark the audit partial and name what did not build
- Do not collapse a multi-targeted repeat into an inflated count, or a distinct site into a deduplicated one
- Do not leave the build log or any temp file behind once the report is produced