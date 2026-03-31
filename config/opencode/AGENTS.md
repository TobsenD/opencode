# Global OpenCode Instructions

## Environment

- You are running as root inside a container.
- You are allowed and expected to install required tools and dependencies as needed.
- Use the appropriate package manager for the task:
  - System tools: `apt-get install -y <package>`
  - Rust: `cargo add`, `rustup component add`
  - Node.js: `npm install` / `pnpm add`
  - Python: `pip install` / `uv add`
  - Go: `go get`
- Always prefer installing tools non-interactively (e.g. `apt-get install -y`).

## Code Quality & Best Practices

- Always follow the **idiomatic best practices** of the language you are working in.
- **Rust:**
  - Run `cargo clippy -- -D warnings` and fix all warnings before finishing.
  - Format code with `cargo fmt`.
  - Write idiomatic Rust (use iterators, avoid unnecessary clones, prefer `?` over `unwrap()`).
- **JavaScript/TypeScript:**
  - Run the project's configured linter (ESLint, Biome, etc.) and fix all issues.
  - Format with Prettier or the project's configured formatter.
- **Python:**
  - Follow PEP 8. Use `ruff` or `flake8` for linting, `black` or `ruff format` for formatting.
- **Go:**
  - Run `go vet` and `golangci-lint` if available.
  - Format with `gofmt` / `goimports`.
- For any other language: research and apply the standard linter and formatter for that ecosystem.
- Fix **all** linter warnings and errors before considering a task complete.

## Git & Commits

- Commit regularly throughout the work – do not wait until everything is done.
- I explicitly request you to commit yourself regularly while working, don't ask me.
- Create at least one commit for every change (feature/bugfix) and don't combine multiple changes. If I ask you for multiple changes in one request, split them into separate commits.
- If you need to fix something you already commited earlier, use `git commit --amend` or `git commit --fixup` to fix the issue from the earlier commit.
- Use **Conventional Commits** for all commit messages:
  - Format: `<type>(<scope>): <description>`
  - Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `style`, `perf`, `ci`
  - Examples:
    - `feat(auth): add JWT token validation`
    - `fix(parser): handle empty input gracefully`
    - `chore: add clippy and rustfmt to CI`
- Write verbose commit messages. Explain why something was needed in the commit message, so is better to understand in the future.
- Add linebreaks after 80 chars in commit messages.
- Write commit messages in **English**.
- Stage only relevant files; do not commit build artifacts, development or debug files (logs, photos, ...), secrets (API keys, passwords, or other credentials), or IDE files.

## Testing

- Write tests for all new functionality where possible.
- Use the standard testing framework of the respective language.
- Run the full test suite before finishing a task and ensure all tests pass.

## General Behaviour

- Before starting, analyze the existing codebase to understand conventions, structure, and patterns already in use.
- Follow the existing code style and architecture of the project.
- Prefer incremental, reviewable changes over large rewrites.
- If a task is ambiguous, ask for clarification before proceeding.
- Do not introduce new dependencies without good reason; prefer the standard library where feasible.
- If dependencies are needed, always use up-to-date versions (if needed upgrade existing dependencies).
- Document public APIs and non-obvious logic with comments.
