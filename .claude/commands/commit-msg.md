Run the following steps to generate and apply a conventional commit message for this project:

## Step 1 — Gather context

Run these commands in parallel:
- `git diff --cached` — staged changes (what will be committed)
- `git diff` — unstaged changes (for context)
- `git status` — list of modified/added/deleted files
- `git log --oneline -10` — recent commits for style reference

## Step 2 — Determine type and scope

Use the staged diff and file paths to pick the correct **type** and **scope**.

### Types (Conventional Commits)
| Type | When to use |
|------|-------------|
| `feat` | New feature or endpoint |
| `fix` | Bug fix |
| `refactor` | Code restructure without behavior change |
| `chore` | Build scripts, dependencies, tooling |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `style` | Formatting, linting (no logic change) |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `build` | Build system or external dependency changes |

### Scopes — infer from changed file paths
| Path pattern | Scope |
|---|---|
| `src/api/src/modules/auth/` | `auth` |
| `src/api/src/modules/users/` | `users` |
| `src/api/src/modules/guides/` | `guides` |
| `src/api/src/modules/catalog/` | `catalog` |
| `src/api/src/modules/{name}/` | `{name}` |
| `src/api/src/core/` | `core` |
| `src/api/prisma/` | `db` |
| `src/frontend/src/app/pages/` | `pages` |
| `src/frontend/src/app/atoms/` | `atoms` |
| `src/frontend/src/app/molecules/` | `molecules` |
| `src/frontend/src/app/organisms/` | `organisms` |
| `src/frontend/src/app/core/` | `frontend-core` |
| `src/frontend/.storybook/` | `storybook` |
| `docker-compose.yml`, `Dockerfile` | `docker` |
| `.github/` | `ci` |
| Root config files | `config` |
| Multiple modules across api+frontend | omit scope |

## Step 3 — Write the commit message

Format: `type(scope): short imperative description`

Rules:
- Subject line: max 72 characters, lowercase after the colon, no period at the end
- Use imperative mood: "add", "fix", "remove", "update" — not "added" or "adds"
- If the change is non-trivial, add a blank line + body explaining the **why**, not the what
- Breaking changes: add `!` after scope and `BREAKING CHANGE:` footer

Examples for this project:
```
feat(guides): add PDF export endpoint with Puppeteer
fix(auth): resolve JWT refresh token rotation race condition
refactor(users): extract password hashing into shared helper
chore(db): add index on guides.created_at for pagination queries
docs(guides): document media API contract
feat(catalog): add media-types and media-options endpoints
style(atoms): apply prettier formatting to button component
test(guides): add unit tests for guide duplication service
```

## Step 4 — Present and apply

1. Show the proposed commit message to the user for review.
2. If the user approves (or says "yes", "ok", "lgtm", "aplícalo"), run:
   ```
   git commit -m "$(cat <<'EOF'
   <the message>
   EOF
   )"
   ```
3. If the user wants changes, adjust and show again before committing.

**Do NOT commit automatically without user confirmation.**
