---
name: "dotnet-preflight"
description: |
  Verifies a .NET backend feature branch is safe to open a PR: solution builds cleanly, EF Core
  migrations are healthy against the local development database resolved from
  appsettings.Development.json, and the application starts without error.
  Not for fixing failing builds, broken migrations, or startup errors — verification only
allowed-tools: Bash Read Grep Glob
model: inherit
disable-model-invocation: true
---

Determine, with evidence you actually executed and observed, whether a .NET backend feature branch is safe to open a PR. Verify the solution builds, EF Core migrations are healthy against the local development database, and the application starts without error. Report findings; never assume a result you have not run and checked yourself

## Operating Modes
### Default — Full Preflight
Run every check in Methodology, including the two that mutate state: applying migrations to the local dev database (Step 3.5–3.6) and starting the application (Step 4). Only this mode can produce a READY verdict

### Fast Mode — Static Only
Activate when the user says "quick check", "static only", "don't touch the db", "don't run it", or otherwise asks to skip execution. Skip `dotnet ef database update`, idempotent script generation, and starting the application. Run every other check. Mark the skipped checks SKIPPED, never PASS, and the overall verdict INCONCLUSIVE rather than READY

## What You Check
### Build Health
- Solution compiles with zero errors
- Every project in the solution builds, not just the startup project

### Migration Health
- Connection string in `appsettings.Development.json` resolves to a real, reachable local database
- DbContext constructs cleanly through DI (`dotnet ef dbcontext info`)
- No model change exists that isn't captured by a migration (`has-pending-model-changes`)
- Migration history is internally consistent — no duplicate names, no ordering conflict with `main`
- Migrations apply cleanly to the actual local dev database (`dotnet ef database update`)
- Migrations regenerate as a valid idempotent script (`dotnet ef migrations script --idempotent`)

### Startup Health
- Compiled application reaches a listening state within a bounded timeout
- No unhandled exception appears in stdout/stderr during startup
- Health endpoint, if one exists, responds successfully once listening

## Methodology
### Step 1 — Discovery
Confirm you're in a git repository; note the current branch. Locate the `.sln` and every `.csproj` not under `bin/` or `obj/`. Identify the web/startup project — the one containing `Program.cs` and `appsettings.Development.json`. Identify every DbContext project via `: DbContext` in source. Confirm `dotnet ef` is available; install it locally (`dotnet tool install --local dotnet-ef`) if missing

### Step 2 — Build
Run `dotnet build <solution>.sln -c Debug --nologo`. A non-zero exit is a hard FAIL. Stop here — report the compiler errors, skip every remaining step

### Step 3 — Migration Verification
For each DbContext project found in Step 1:
1. Read the connection string from `appsettings.Development.json`. Redact the password before it appears anywhere in output.
2. Run `dotnet ef dbcontext info --project <ctx> --startup-project <web>`
3. Run `dotnet ef migrations has-pending-model-changes --project <ctx> --startup-project <web>`. Skip with a note if the installed EF Core version doesn't support it
4. Run `dotnet ef migrations list --project <ctx> --startup-project <web>`. Cross-check migrations new on this branch against `git diff main...HEAD --name-only -- '**/Migrations/*'`
5. Default mode only: run `dotnet ef database update --project <ctx> --startup-project <web>`
6. Default mode only: run `dotnet ef migrations script --idempotent -o /tmp/dotnet-preflight-migrations.sql --project <ctx> --startup-project <web>`

A check is PASS only if its command exits zero and its output shows no error. In Fast Mode, 5 and 6 are SKIPPED, never PASS

### Step 4 — Startup Verification (Default mode only; SKIPPED in Fast Mode)
Build already succeeded in Step 2. Run the compiled output directly — `dotnet <project-dir>/bin/Debug/<tfm>/<AssemblyName>.dll` — rather than `dotnet run`, so there is one process to track instead of a parent and a spawned child. Redirect output to a temp log file. Poll up to 30s for a success marker (`Now listening on`, `Application started`) or a failure marker (`Unhandled exception`, a stack trace). If a health endpoint exists, curl it once listening. Kill the process — and its process group if you used `dotnet run` instead — regardless of outcome

### Step 5 — Report
Produce the Output Format below. Include every check that ran, including SKIPPED ones. Do not stop at the first failure — run every step that doesn't depend on a failed one, and report all failures together

## Decision Framework
1. Would this check mutate anything outside the local database resolved from `appsettings.Development.json`? If yes, only run it in Default mode
2. Can you support the result with something you actually executed — an exit code, a log line, a generated file? If no, report it as inconclusive, not PASS
3. Did an earlier step fail in a way that makes this one meaningless? If yes, mark it N/A and say why — don't run it anyway
4. Would resolving this finding require changing application code? If yes, don't change it — report it as required follow-up
5. Is a process still running, or a temp file still present, after this check finishes? If yes, clean it up before moving on

## Output Format
For each check:
1. Check — what was verified
2. Command — the exact command run
3. Result — PASS / FAIL / SKIPPED / N/A
4. Evidence — exit code, matched log line, or error text (redact any credential)

Close with:

```
## Verdict — branch: <branch-name>
READY FOR PR / NOT READY / INCONCLUSIVE (Fast Mode — mutating checks skipped)
```

If NOT READY, add a "Required follow-up" list — the exact command or fix needed for each FAIL, not a general suggestion.

## Hard Limits
- Do not modify application code, migrations, or configuration files — this skill verifies, it does not fix
- Do not run `dotnet ef database update` or start the application outside Default mode
- Do not apply migrations to, or start the application against, any connection string other than the one resolved from `appsettings.Development.json`
- Do not print connection string passwords or credentials into the report, even for a local dev database
- Do not report PASS for a check that did not actually execute
- Do not leave a process running or a temp file behind once a check completes
- Do not skip a step because an earlier one looked fine — run every step Steps 1–4 list
- Do not fix a failing build, migration, or startup error you encounter along the way — report it and stop