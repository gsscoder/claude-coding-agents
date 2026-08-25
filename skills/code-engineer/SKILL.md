---
name: "code-engineer"
description: |
  Language-agnostic engineering discipline for writing and changing code: naming, responsibilities,
  complexity, control flow, state, errors, coupling, abstraction, testability, concurrency,
  performance, and change hygiene.
  Load before editing source; apply while editing. Not a review report, not a refactoring campaign —
  it constrains the change at hand
model: inherit
---

Apply these rules to every unit of code you write, modify, or review in this session

## Operating modes
### Coder — default
Apply while writing or editing code: act on a fired trigger by editing the unit under change. Default for bare `/code-engineer` invocation and for any caller that does not name a mode

### Reviewer
Apply when invoked to review, audit, or report on code without changing it, or by a caller with no write access. Act on a fired trigger by recording the finding — location, rule, verdict — never by editing. Silence on a rule that did not fire; no restating rules that did not trigger

## How to apply
Every numeric threshold is a trigger for inspection, not a target for compliance. When one fires, analyze responsibilities first and act — edit in Coder mode, flag in Reviewer mode — only if the analysis finds a real seam
Never satisfy a rule mechanically — extracting `helperA`/`helperB`, renaming to dodge a check — without improving the design
When a trigger fires and the code is correct as written, record that verdict in one line and move on
Report only what you ran, and name what you did not verify
Consistency with the surrounding codebase outweighs any rule here. If a rule forces a change that makes the code worse, record why and skip it

## Naming
Name what a thing is and why it exists, never how it is implemented or what type it is
Scale name length with scope: single letters only inside a few lines
One word per concept across the codebase — never alternate `fetch`/`get`/`retrieve` for the same operation
Avoid negated booleans: `enabled`, not `notDisabled`
Include units and ranges where they exist: `timeoutMs`, `ratioPercent`, `offsetBytes`
`And`, `Or`, `Then` in a name is a defect report: split the unit, or find the single name that is missing. A name that needs a conjunction means the behavior is not yet understood
Vague names — `process`, `handle`, `manage`, `doWork`, `data`, `info` — are the same defect in disguise
If two readers disagree about what a unit does, its name or its scope is wrong

## Responsibilities
A unit has one reason to change, not merely "does one thing". Identify responsibilities by asking who would request a change to this code; two distinct requesters means two responsibilities
State what the unit does in one short sentence. If the sentence needs a conjunction, split the unit; otherwise refactor until the code reads as that sentence
Keep every statement in a function at the same level of abstraction
Before splitting tangled code, inline the existing helpers to see the whole shape, then cut along the real seams
Prefer grouping cohesive locals into an object, or promoting the function to a type with methods, over extracting arbitrary sub-functions

## Size and complexity
A function that no longer fits on one screen — or that a reader must scroll to hold — is a prompt to look for a seam
Count statements and live locals, not physical lines; formatter-driven breaks are not complexity. Keep the set of variables live at any point small enough to hold in working memory
Keep nesting depth at or below three; four is a defect waiting to happen
When a metric is needed, prefer cognitive complexity (penalizes nesting) over cyclomatic complexity (penalizes branch count)
Accept long linear code — dispatch tables, sequential setup, exhaustive matches — over short deeply nested code
More than three or four parameters usually signals a missing type. Never add a boolean parameter that switches behavior; write two functions
Count collaborators as complexity: a trivial function touching eight objects is still coupled

## Control flow
Use guard clauses and early returns instead of nested conditionals: handle errors and edge cases first, leave the main path unindented at the end
Make matches exhaustive so the compiler or linter can prove no case is missing
Never encode business logic in short-circuit chains or implicit fallthrough
Avoid flag variables that steer control flow far from where they are set

## State and data
Default to immutable values; mutate only where a measured reason exists
Declare variables at the narrowest scope and as late as possible
Make illegal states unrepresentable in the type or data model wherever the language allows, and wrap identifiers and quantities in distinct types rather than passing primitives
Validate at the boundary, then trust the value inside — do not re-check the same invariant everywhere
Keep the core pure and push side effects to the edges. Never read ambient state — clock, environment, randomness, global config — inside logic; pass it in

## Errors
Distinguish expected failures from bugs: model the first in the return type, let the second fail loudly, close to the source of the invalid value
Never swallow an error; an empty catch block is a defect, and wrapping must not lose the original cause
Every error states what was attempted, with which inputs, and which constraint was violated
Never use exceptions or error returns for ordinary control flow

## Dependencies and coupling
Depend on interfaces you own; wrap third-party shapes at the boundary instead of spreading them
Inject dependencies rather than constructing them inside the unit that uses them
Forbid cyclic dependencies between modules
Keep a module's public surface as small as its callers require
Talk to immediate collaborators only; never reach through an object to its internals

## Duplication and abstraction
No new helper duplicates one already in the repo or the standard library; extend the existing one or use it
Deduplicate knowledge, not text: identical lines that change for different reasons stay separate
Prefer duplication over the wrong abstraction — duplication is local and cheap to undo. Wait for the third occurrence before generalizing
Add no extension point, parameter, or layer for a requirement that does not yet exist
Delete an abstraction that has exactly one caller and no prospect of a second

## Comments
Comment why, not what. If the what is unclear, fix the code — a block that needs a comment to explain what it does wants extraction, with the name as the comment
Documentation that restates the signature is noise; document the contract or write none
Document invariants, preconditions, units, and resource ownership
Prefer executable documentation — types, assertions, tests — over prose that can go stale silently
Remove commented-out code; version control is the archive

## Testability
Write code whose tests need no mocks: pure cores, injected dependencies, deterministic time and randomness
Assert on behavior at the public boundary, never on internals
A hard-to-test unit is a design report, not a testing problem
Every branch must be reachable by a test; unreachable branches are dead or wrongly guarded

## Concurrency
Never share mutable state across threads; communicate through queues, messages, or transactions
Thread-safety is an explicit, documented property of a type, never an assumption
Keep critical sections short and free of calls into unknown code
Never rely on timing, sleeps, or execution order for correctness

## Performance
Measure before optimizing; never act on intuition about hot paths
Fix algorithmic complexity and I/O patterns before constant factors
Never obscure code for an unmeasured gain. Where optimized code is unavoidable, isolate it and state the semantics it preserves

## Scope
Only what the task requires is present: an unrequested feature, flag, option, or configuration point is a defect even when it works
No scaffolding for later — no entry point, re-export layer, argument parsing, or logging that nothing yet calls
No compatibility shim, alias, or deprecation path for code that has no released callers
Never present a stub as an implementation: unimplemented means the code fails loudly and the report says so, not a hardcoded return

## Change hygiene
Keep refactoring changes separate from behavior changes
Leave each touched file slightly better than found, without unrelated rewrites
Delete dead code rather than disabling it
Make each change reviewable on its own: a diff that cannot be read is a diff that is not reviewed