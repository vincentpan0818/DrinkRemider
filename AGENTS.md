# AGENTS.md
Guidance for autonomous coding agents operating in this repository.
## Repository State
- At creation time, repository root is empty.
- No build scripts, dependencies, or tests were detected yet.
- Treat this as a living guide and refine when stack files appear.
## Instruction Priority
- 1) Direct user instructions for the current task.
- 2) This `AGENTS.md` file.
- 3) Repo-local tool config and script files.
- 4) Framework defaults.
## Cursor and Copilot Rules
- Checked `.cursor/rules/`: not present.
- Checked `.cursorrules`: not present.
- Checked `.github/copilot-instructions.md`: not present.
- If added later, follow them as high-priority repo rules.
- If rule files conflict, prefer path-specific and newer guidance.
## Stack Detection Checklist
- Look for JS/TS markers: `package.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `bun.lock`.
- Look for Python markers: `pyproject.toml`, `requirements.txt`, `poetry.lock`, `uv.lock`, `tox.ini`.
- Look for Go markers: `go.mod`.
- Look for Rust markers: `Cargo.toml`.
- Look for Java/Kotlin markers: `pom.xml`, `build.gradle`, `build.gradle.kts`.
- Look for Ruby markers: `Gemfile`.
- Look for PHP markers: `composer.json`.
- Look for C# markers: `*.sln`, `*.csproj`.
- Prefer project-defined scripts over guessed commands.
## Build Commands
- Use the first applicable command set based on discovered tooling.
### Node.js / TypeScript
- Install: `npm ci` (or `pnpm install --frozen-lockfile` / `yarn install --frozen-lockfile`).
- Build: `npm run build`.
- Dev build/watch: `npm run dev` or `npm run watch`.
- Typecheck: `npm run typecheck` (if script exists).
### Python
- Install (pip): `python -m pip install -r requirements.txt`.
- Install (Poetry): `poetry install`.
- Build package: `python -m build`.
- Typecheck: `mypy .` or `pyright` if configured.
### Go
- Build all: `go build ./...`.
- Vet all: `go vet ./...`.
### Rust
- Build: `cargo build`.
- Check: `cargo check`.
## Lint and Format Commands
- Run lint before finalizing code changes.
- Use repo scripts first when available.
### Node.js / TypeScript
- Lint: `npm run lint`.
- Lint fix: `npm run lint -- --fix` (if supported).
- Format check: `npm run format:check` or `prettier --check .`.
- Format write: `npm run format` or `prettier --write .`.
### Python
- Lint: `ruff check .`.
- Format check: `ruff format --check .`.
- Format write: `ruff format .`.
### Go
- Format: `go fmt ./...`.
### Rust
- Lint: `cargo clippy --all-targets --all-features -D warnings`.
- Format check: `cargo fmt -- --check`.
- Format write: `cargo fmt`.
## Test Commands (Single-Test First)
- Default strategy: run narrow tests first, then broader suite.
### Node.js / TypeScript (Jest or Vitest)
- All tests: `npm test` or `npm run test`.
- Single test file: `npm test -- path/to/file.test.ts`.
- Single test by name: `npm test -- -t "test name"`.
- Vitest single file explicit: `npx vitest run path/to/file.test.ts`.
### Python (pytest)
- All tests: `pytest`.
- Single file: `pytest tests/test_module.py`.
- Single test function: `pytest tests/test_module.py::test_specific_case`.
- Name filter: `pytest -k "specific_case"`.
### Go
- All tests: `go test ./...`.
- Single package: `go test ./path/to/package`.
- Single test: `go test ./path/to/package -run TestName`.
### Rust
- All tests: `cargo test`.
- Single test by name fragment: `cargo test test_name_fragment`.
- Single integration target: `cargo test --test integration_test_file`.
## Code Style Guidelines
### Imports
- Group imports by standard library, third-party, then local modules.
- Keep import order deterministic using formatter/linter.
- Remove unused imports before finalizing changes.
- Prefer explicit imports over wildcard imports.
### Formatting
- Use the formatter configured by the repository.
- Do not hand-format against automated tooling.
- Respect line length and whitespace rules from config.
- Keep diffs clean by avoiding unrelated reformatting.
### Types
- Prefer explicit types on API boundaries.
- Avoid `any` or untyped escapes unless necessary.
- Narrow parsed/external input early.
- Model domain concepts with clear, stable types.
### Naming
- Choose descriptive names over abbreviations.
- Use verb-centric names for functions (`createInvoice`).
- Use noun-centric names for values (`invoiceTotal`).
- Use language-idiomatic casing for functions and variables.
- Use PascalCase for classes/types where idiomatic.
### Error Handling
- Fail fast on invalid states with actionable messages.
- Do not swallow exceptions silently.
- Add context when rethrowing or returning errors.
- Prefer typed/domain errors for expected failures.
- Keep sensitive internals out of user-facing messages.
### Logging
- Use structured logs where available.
- Include request/entity identifiers when useful.
- Never log secrets, tokens, or private data.
- Use consistent log levels (`debug`, `info`, `warn`, `error`).
### Testing Standards
- Add/update tests for every behavior change.
- Keep tests deterministic and fast.
- Mock only external boundaries, not core logic.
- Add regression tests for bug fixes.
### Git Hygiene
- Keep commits focused on one logical change.
- Avoid unrelated refactors in bug-fix or feature PRs.
- Update docs when behavior or commands change.
- Never commit credentials or local env secrets.
## Execution Workflow for Agents
- Detect stack and local scripts first.
- Implement minimal, correct change.
- Run targeted test(s) for touched behavior.
- Run lint/format/typecheck as available.
- Run broader tests when practical.
- Report what ran and what could not be verified.
## If Tooling Is Missing
- Do not scaffold major tooling unless requested.
- Prefer lightweight validation if possible.
- Clearly note unverified areas in final report.
## Keeping This File Current
- Update this file whenever build/test/lint commands change.
- Add exact single-test commands for new frameworks.
- If Cursor/Copilot rules are added, mirror key points here.
