# Contributing

These rules apply to humans and agents alike. Use the terms in [GLOSSARY.md](GLOSSARY.md), and read the decisions in [docs/adr/](docs/adr/) before changing anything they cover.

## Workflow

- **Trunk-based.** Commit small, working changes directly to `main`. No long-lived branches; other branches are only for throwaway experiments.
- **One-time setup:** follow [Development setup](README.md#development-setup) in the README. `pre-commit install` installs both the `pre-commit` and `commit-msg` hooks. Keep shellcheck on your PATH: actionlint only checks workflow shell scripts when it is there, and CI always has it. The hook tools are pinned in `.pre-commit-config.yaml`, and pre-commit downloads them on first use.
- **Every commit must pass the hooks.** If a hook fails or changes files, fix the problem, `git add -u`, and commit again. Never use `--no-verify`. CI runs the same checks and will fail anyway.
- **Only the pipeline deploys.** Don't deploy from a laptop.

## Commit messages

We follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

- **description**: imperative mood, lower case, no full stop, 72 characters or fewer for the whole first line. Examples: "add", "fix", "remove". Not "added" or "adds".
- **body**: optional. Explain _why_ the change was made, not what changed; the diff shows what. Wrap at 72 characters and leave a blank line after the first line.
- **footers**: `BREAKING CHANGE: <what breaks and how to migrate>`, `Refs: #<issue>`, `Co-Authored-By: <name> <email>`.
- **Breaking changes**: put `!` after the type or scope (`feat!: ...`, `feat(<scope>)!: ...`) _and_ add a `BREAKING CHANGE:` footer.
- **One logical change per commit.** If the description needs "and", split the commit.

### Types

`feat` and `fix` are **only** for changes the person using the project can see. Tooling can't check this, so choose carefully.

| Type       | Use for                                                          |
| ---------- | ---------------------------------------------------------------- |
| `feat`     | A new capability the person using the project can see            |
| `fix`      | A bug fix the person using the project can see                   |
| `refactor` | A code change with no change in behaviour                        |
| `perf`     | A performance improvement                                        |
| `test`     | Adding or changing tests only                                    |
| `docs`     | Documentation only: README, GLOSSARY, ADRs, this file            |
| `build`    | Build tooling, dependencies, config                              |
| `ci`       | GitHub Actions workflows, the pre-commit and commitlint config   |
| `chore`    | Anything else                                                    |
| `revert`   | Reverting an earlier commit. The body should say `Reverts <sha>` |

### Scopes

The scope is optional but encouraged. The base scopes are:

| Scope  | Covers                                      |
| ------ | ------------------------------------------- |
| `deps` | Dependency bumps (with `build` or `ci`)     |
| `adr`  | Architecture decision records (with `docs`) |

Each project adds its glossary terms as scopes, so scopes follow the domain language.

The allowed types and scopes, and the 72-character limits, are enforced by commitlint at the `commit-msg` stage (`commitlint.config.mjs`). **Change the commit-lint config and this file together.** Dependabot's commits (`Signed-off-by: dependabot[bot]`) are not linted, because their bodies carry release notes with long lines.

commitlint runs through pre-commit, which provisions Node for it, so a project needs no npm to lint its commits. The lighter `conventional-pre-commit` was the first choice, but it can't enforce the length limits or skip Dependabot's commits.

### Examples

```
docs(adr): record copying standards into projects
```

```
ci: run shellcheck on scripts

actionlint only checks workflow scripts, so a broken helper script
passed the hooks and failed later in CI.
```

```
ci(deps): bump gitleaks to v8.30.0
```
