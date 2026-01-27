Run the project's check/test command.

Detect project type and run appropriate checks:
- If Makefile with `check` target: `make check`
- If package.json with test script: `npm test` / `pnpm test`
- If Cargo.toml: `cargo test && cargo clippy`

Report results clearly.
