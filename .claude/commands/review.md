Review and validate the latest code changes for quality, correctness, and optimization opportunities. Act as a senior code reviewer.

## Step 1 — Gather the diff

Run these commands in parallel:
- `git diff HEAD~1 HEAD` — changes in the last commit
- `git diff` — any unstaged changes not yet committed
- `git diff --cached` — staged but uncommitted changes
- `git status` — full picture of the working tree
- `git log --oneline -5` — recent commit context

If there are no uncommitted changes and no recent commit diff, tell the user and stop.

## Step 2 — Read the changed files

For every file that appears in the diff, read the **full file** (not just the diff chunk) to understand the surrounding context. This is essential for spotting issues that are invisible from the diff alone (missing imports, broken interfaces, side effects, etc.).

## Step 3 — Analyse the changes

Evaluate the code across these dimensions. Only flag items that are **actually present** in the diff — do not invent issues.

### 3.1 Correctness & Bugs
- Logic errors, off-by-one, missing null/undefined guards at system boundaries (user input, API responses)
- Incorrect use of async/await, missing `await`, unhandled Promise rejections
- Angular: signal reads outside reactive context, missing `takeUntilDestroyed` on subscriptions
- NestJS: missing decorators, incorrect DI tokens, unguarded route handlers

### 3.2 Security
- Injection risks: unsanitised user input passed to SQL, shell, or HTML
- Secrets or credentials hardcoded in source
- Missing auth guards on new endpoints
- CORS misconfigurations or overly permissive headers

### 3.3 Performance
- N+1 queries (Prisma `include` inside a loop)
- Missing `async`/`defer` or heavy synchronous operations on the main thread
- Angular: unnecessary `computed()` recalculations, large component trees without `OnPush` or signals
- Unbounded queries without pagination or `take` limit

### 3.4 Architecture & Conventions (project-specific)
- Frontend: Atomic Design violations (e.g. business logic in an atom, direct API calls outside `core/services/`)
- Backend: logic leaking into controllers instead of services; missing DTOs for new inputs
- File/class naming: kebab-case files, PascalCase classes, conventional commit scope matches changed path
- Strict TypeScript: `any`, missing return types, suppressed errors (`// @ts-ignore`)

### 3.5 Code Quality & Readability
- Dead code: unused variables, imports, exported symbols
- Duplicated logic that could reuse an existing helper or service
- Overly complex functions that could be extracted (> ~40 lines doing multiple things)
- Missing or misleading comments where the logic is genuinely non-obvious

### 3.6 Tests
- New logic paths without test coverage
- Tests that mock too aggressively and would miss real regressions (per project convention: prefer integration tests over mocks)

## Step 4 — Generate the report

Structure the output as follows. Skip any section that has zero findings.

---

## Code Review — `<branch or commit ref>`

### Summary
One-paragraph executive summary: what changed, overall quality, headline risks.

### Findings

Use this format for each finding:

**[SEVERITY] Category — short title**
- **File**: `path/to/file.ts:line`
- **Issue**: What is wrong or suboptimal.
- **Suggestion**: Concrete fix or improvement, with a code snippet when helpful.

Severity levels:
- `[CRITICAL]` — Bug, security hole, or data loss risk. Must fix before merging.
- `[WARNING]` — Likely to cause problems under certain conditions. Should fix.
- `[SUGGESTION]` — Improvement opportunity: performance, readability, or convention. Optional but recommended.
- `[PRAISE]` — Something done particularly well. Worth calling out to reinforce good patterns.

### Quick-fix checklist
A bullet list of the `[CRITICAL]` and `[WARNING]` items as actionable tasks, so the developer can work through them quickly.

### Verdict
One of:
- **Ready to merge** — no critical or warning issues found
- **Needs minor fixes** — only suggestions remain after addressing warnings
- **Needs work** — one or more critical or warning issues must be resolved first

---

Be direct and specific. Reference exact file paths and line numbers. Provide code snippets for non-trivial suggestions. Do not pad the report with generic advice that does not apply to the actual diff.
