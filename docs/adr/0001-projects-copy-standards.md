# Projects copy standards rather than link to them

Projects copy the standard files (`.gitignore`, `CONTRIBUTING.md`, the development practices, the hook fragments) from the standards repo, each with a source header naming the commit it came from, rather than referencing them live. Stack hook fragments are copied as `repo: local` hooks that run the project's tools from its own lockfile, not published as remote pre-commit hooks from the standards repo, because pre-commit runs remote hooks in an isolated environment that can't see the project's own plugins or tool versions. Copying also keeps each project self-contained for agents in the cloud and in worktrees, at the cost of drift, which the source header makes visible.

## Considered Options

- **Live reference** (a `.pre-commit-hooks.yaml` in the standards repo, docs linked by URL): one source and never stale, but the hooks would lose access to the lockfile, and a project's gates could change without a commit in that project.
- **Copy with a source header** (chosen).
