---
name: "react-preflight"
description: |
  Verifies a React frontend feature branch is safe to open a PR: dependencies install from a
  lockfile that isn't drifted, the app typechecks and builds for production, the test suite is
  green and actually ran, and both the dev server and the production build start without error.
  Not for fixing failing builds, broken types, or red tests — verification only
allowed-tools: Bash Read Grep Glob mcp__claude-in-chrome__tabs_create_mcp mcp__claude-in-chrome__navigate mcp__claude-in-chrome__get_page_text mcp__claude-in-chrome__read_console_messages mcp__claude-in-chrome__read_network_requests mcp__claude-in-chrome__tabs_close_mcp
model: inherit
disable-model-invocation: true
---

Determine, with evidence you actually executed and observed, whether a React frontend feature branch is safe to open a PR. Verify dependencies install cleanly, the app typechecks and lints, the test suite is genuinely green, the production build succeeds, and both the dev server and the production build start without error. Report findings; never assume a result you have not run and checked yourself

## Operating Modes
### Default — Full Preflight
Run every check in Methodology, including the two that mutate state: a clean dependency install (Step 2) and starting the dev server and production preview (Step 6). Only this mode can produce a READY verdict

### Fast Mode — Static Only
Activate when the user says "quick check", "static only", "don't reinstall", "don't run it", or otherwise asks to skip execution. Skip the clean install and both server starts. Run every other check — typecheck, lint, tests, and build mutate nothing but `node_modules`/`dist`. Mark the skipped checks SKIPPED, never PASS, and the overall verdict INCONCLUSIVE rather than READY

### Browser Mode — Render Proof (opt-in add-on to Default)
Activate only when the user explicitly asks for it — "check it in the browser", "browser mode", "verify it actually renders". Not run by default, since it needs the `claude-in-chrome` MCP server, which may not be installed in the target project

Runs after Step 6's production preview is up. If the first `mcp__claude-in-chrome__*` call fails (server not connected), mark this section SKIPPED with that reason and continue — this is a soft dependency, never a preflight blocker

## What You Check
### Dependency Health
- Exactly one lockfile present — two lockfiles (e.g. `package-lock.json` and `pnpm-lock.yaml`) is a finding on its own
- Package manager and its immutable-install command derived from the lockfile found: `npm ci`, `pnpm install --frozen-lockfile`, or `yarn install --immutable`
- Installed Node version satisfies `engines.node` in `package.json`, if set
- Install exits zero and rewrites nothing tracked by git — a lockfile that changes after an "immutable" install means `package.json` and the lockfile have drifted

### Static Health
- Typecheck passes with zero errors — the repo's own `typecheck` script if one exists, else `tsc --noEmit` when a `tsconfig.json` is present
- Lint passes with zero errors — the repo's own `lint` script. New warnings introduced on this branch (vs `main`) are reported; pre-existing warnings are not a FAIL
- Format check only if the repo already defines the script — never invent one

### Test Health
- Test runner detected from `package.json` (vitest, jest, `react-scripts test`, etc.) and forced non-interactive (`--run`, `CI=true`, `--watchAll=false`) — a watch-mode hang is the most common way this check silently never finishes
- Exit code zero AND reported test count > 0 — zero collected tests exiting zero is a FAIL, not a PASS
- No `.only`/`fdescribe`/`fit` introduced on this branch vs `main` — a single focused test turns the rest of the suite green by never running it
- No newly `.skip`-ed test introduced on this branch vs `main`
- No test script present at all: mark N/A with a note, never a silent PASS

### Build Health
- Production build (`npm run build` or repo equivalent) exits zero and emits a non-empty output directory
- Catches failures typecheck misses: unresolved dynamic imports, missing asset references, bad base path

### Runtime Health
- Dev server reaches a listening state within a bounded timeout, no unhandled error in stdout/stderr during startup
- Production preview (`vite preview`, `next start`, or equivalent) serves the built output; a request to `/` returns 200 with the app's mount node present in the HTML — a build that exits zero can still preview-serve a stale or empty shell

### Render Health (Browser Mode only)
- Preview page's mount node (e.g. `#root`, `#app`) has child nodes after load — an HTML 200 with an empty mount node is a white screen the HTTP-only check in Runtime Health cannot see
- Zero uncaught console errors during first render
- Zero failed network requests (404s) for chunks or assets — the usual signature of a broken `base`/`publicPath`

### Branch Hygiene
- `debugger` statements or stray `console.log` introduced on this branch vs `main`
- New dependencies added on this branch, listed for the reviewer
- New `VITE_*`/`NEXT_PUBLIC_*` (or equivalent) env vars referenced in source on this branch but absent from `.env.example`

## Methodology
### Step 1 — Discovery
Confirm you're in a git repository; note the current branch. Locate `package.json` at the project root (or the target passed as an argument, if a monorepo). Identify the lockfile present and the package manager it implies. Read `package.json` `scripts` to find the real `dev`, `build`, `test`, `lint`, `typecheck`, and `preview` commands — prefer the repo's own script names over inventing a command

### Step 2 — Install (Default mode only; SKIPPED in Fast Mode)
Run the immutable install for the detected package manager. Non-zero exit is a hard FAIL — stop, report the error, skip every remaining step. After it exits zero, run `git status --porcelain` on the lockfile; any diff is a FAIL even though the command itself exited zero

### Step 3 — Typecheck and Lint
Run the repo's `typecheck` script, else `tsc --noEmit` if `tsconfig.json` exists, else mark N/A. Run the repo's `lint` script. Cross-check new lint warnings against `git diff main...HEAD --name-only`

### Step 4 — Tests
Run the repo's `test` script with the non-interactive flag appropriate to the detected runner. Parse the summary line for collected test count. Search test files changed on this branch (`git diff main...HEAD --name-only -- '**/*.test.*' '**/*.spec.*'`) for `.only`/`.skip` additions

### Step 5 — Build
Run the repo's `build` script. Confirm the output directory exists and is non-empty. Record output size per top-level chunk when the build tool reports it

### Step 6 — Runtime Verification (Default mode only; SKIPPED in Fast Mode)
Start the dev server with output redirected to a temp log file. Poll up to 30s for a success marker (`Local:`, `ready in`, `compiled successfully`) or a failure marker (unhandled error, stack trace). Kill it and free the port regardless of outcome

Then start the production preview server against the Step 5 build output the same way. Once listening, request `/` and confirm a 200 and that the mount node (e.g. `#root`, `#app`) appears in the returned HTML. Kill it and free the port regardless of outcome

### Step 7 — Render Verification (Browser Mode only)
Skip entirely unless Browser Mode is active. Open a new tab with `mcp__claude-in-chrome__tabs_create_mcp`, navigate to the Step 6 preview URL, then read `mcp__claude-in-chrome__get_page_text` to confirm the mount node rendered content, `mcp__claude-in-chrome__read_console_messages` for uncaught errors, and `mcp__claude-in-chrome__read_network_requests` for failed asset loads. Close the tab with `mcp__claude-in-chrome__tabs_close_mcp` regardless of outcome. Never trigger a JS `alert`/`confirm`/`prompt` while doing this — it blocks the tab

### Step 8 — Report
Produce the Output Format below. Include every check that ran, including SKIPPED ones. Do not stop at the first failure — run every step that doesn't depend on a failed one, and report all failures together

## Decision Framework
1. Would this check mutate `node_modules`, the lockfile, or bind a port? If yes, only run it in Default mode
2. Can you support the result with something you actually executed — an exit code, a log line, a generated file? If no, report it as inconclusive, not PASS
3. Did an earlier step fail in a way that makes this one meaningless? If yes, mark it N/A and say why — don't run it anyway
4. Would resolving this finding require changing application code, config, or the lockfile? If yes, don't change it — report it as required follow-up
5. Is a server still running, or a temp file still present, after this check finishes? If yes, clean it up before moving on

## Output Format
For each check:
1. Check — what was verified
2. Command — the exact command run
3. Result — PASS / FAIL / SKIPPED / N/A
4. Evidence — exit code, matched log line, or error text

Close with:

```
## Verdict — branch: <branch-name>
READY FOR PR / NOT READY / INCONCLUSIVE (Fast Mode — mutating checks skipped)
```

If NOT READY, add a "Required follow-up" list — the exact command or fix needed for each FAIL, not a general suggestion.

## Hard Limits
- Do not modify application code, `package.json`, the lockfile, or any `.env` file — this skill verifies, it does not fix
- Do not pass `--force` or `--legacy-peer-deps` (or equivalent) to make an install succeed — that hides a real finding
- Do not run the immutable install or start any server outside Default mode
- Do not report tests green without a collected-test count greater than zero
- Do not report PASS for a check that did not actually execute
- Do not leave a server running or a bound port or temp file behind once a check completes
- Do not skip a step because an earlier one looked fine — run every step Steps 1–6 list
- Do not fail the overall verdict because Browser Mode is unavailable — mark it SKIPPED and continue; it is a soft dependency on the `claude-in-chrome` MCP server, not a hard requirement
- Do not click, submit, or interact with anything on the previewed page beyond navigating and reading — Browser Mode observes, it does not exercise the app
- Do not fix a failing build, type error, lint error, or red test you encounter along the way — report it and stop
