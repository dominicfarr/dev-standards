# Plan: dev-standards

## Goal

Stop repeating the same setup at the start of every project. One **standards repo** holds Dom's standard files and **development practices**. One skill, `new-project`, creates a project from them. Everything after that goes through the normal Pocock flow, `grill-with-docs` → `to-spec` → `to-tickets` → `implement`, with grilling reading the development practices as settled scope.

Terms are defined in [GLOSSARY.md](GLOSSARY.md). Why projects copy files rather than link to them: [ADR 0001](docs/adr/0001-projects-copy-standards.md).

Source material: [docs/bootstrap-from-playlist-transfer.md](docs/bootstrap-from-playlist-transfer.md) and [docs/playlist-transfer-full-notes.md](docs/playlist-transfer-full-notes.md). The reference implementation is `dominicfarr/playlist-transfer`.

## Deliverables

### 1. This repo becomes the standards repo

`dominicfarr/dev-standards` (renamed from `my-bootstrap`; the local folder rename can come later). It holds:

| File | Purpose |
|---|---|
| `.gitignore` | One standard file covering Python, Svelte/JS/TS, Docker, AWS, macOS, editors, `.claude/`, secrets (`.env*`, `*.pem`, `*.key`, `*.p8`), logs, and a commented section for local working files |
| `CONTRIBUTING.md` | Trunk-based workflow, Conventional Commits 1.0.0, the types table (`feat`/`fix` only for user-visible changes), base scopes `deps` and `adr` (projects add their glossary terms), "change the commit-lint config and this file together" |
| `docs/DEVELOPMENT.md` | The development practices (see below) |
| `.pre-commit-config.yaml` | Base gates: gitleaks, actionlint, shellcheck-py, and commitlint at the `commit-msg` stage, run by pre-commit so it needs no npm (`conventional-pre-commit` can't enforce the length limits or skip Dependabot) |
| `.github/workflows/ci.yml` | Base CI: on every push, run pre-commit across all files and lint every commit in the push. It has a marked extension point for each stack's test and build steps |
| `.github/dependabot.yml` | Base: weekly, grouped `github-actions` updates (prefix `ci`) |
| `hooks/python.yaml`, `hooks/js-ts.yaml` | Hook fragments: `repo: local` hooks that run each stack's tools from the project's lockfile (ruff, pyright via `uv run`; eslint, prettier, svelte-check, vitest via `npx --no-install`) |
| `templates/sonar.yml`, `templates/sonar-project.properties` | Sonar workflow and base properties, copied when a project's Sonar ticket is worked |

The repo follows its own standards: it uses the base gates and `CONTRIBUTING.md` itself.

### 2. The development practices (`docs/DEVELOPMENT.md`)

Written for grilling agents and for Dom. Grilling treats each section as settled scope and turns the parts that apply into tickets.

- **Delivery:** trunk-based on `main`, minimumcd.org: CI on every push, the checks gate the deploy, only the pipeline deploys, from one build artifact.
- **Local gates:** pre-commit installed with `uv tool install pre-commit==<pin>`, the same pin in CI. Any hook that fails or changes files stops the commit, and `--no-verify` is never used.
- **Stacks:** Python uses uv. JS/TS (Svelte) uses npm. For each stack: merge its hook fragment, add its CI test and build steps, add its Dependabot ecosystem (prefix `build`), append to the README *Development setup* section.
- **Pinning:** every action pinned to a commit SHA, with the version as a comment, at the latest release within the current major version. Dependabot proposes major upgrades.
- **Sonar:** human steps first (import into the `dominicfarr` organization, turn Automatic Analysis off, create a project analysis token, `gh secret set SONAR_TOKEN --repo …`). The agent's ticket checks they're done, then copies the templates, runs the first-analysis triage and adds the badges.
- **Repo metadata:** the About description and topics once `PLAN.md` exists. Badges: CI with the base CI; quality gate and coverage with Sonar.
- **License:** none by default (all rights reserved).
- **Secrets:** only Dom sets them, always with `--repo`. Values never go through an agent.
- **Gotchas:** the project-agnostic list from the source notes.

### 3. `new-project` skill, in `dominicfarr/claude-skill-lab`

Add `.claude-plugin/plugin.json` and `marketplace.json` so the lab installs with `/plugin install`, and retire the `.claude/commands/` shim. Add `skills/new-project/SKILL.md`. In an empty or near-empty folder, it:

1. runs `git init` on `main`
2. copies the standard files and base gates from `dominicfarr/dev-standards` with `gh`, each with a source header naming the commit it read
3. runs `setup-matt-pocock-skills` (GitHub tracker, default triage labels, single-context domain docs)
4. adds a "Read first" line to `CLAUDE.md`: `PLAN.md`, `GLOSSARY.md`, `docs/adr/`, `docs/DEVELOPMENT.md`, `CONTRIBUTING.md`
5. installs the hooks and makes the first commit, which must pass them
6. runs `gh repo create <name> --public --source=. --push`, then creates the triage labels

## Out of scope (for now)

- Hosting and deploy (S3, CloudFront, Route 53, the OIDC deploy role)
- Folder layout for projects that use both stacks
- Keeping copied files in step with the standards repo (the source header makes drift visible, and a sync tool comes later)
- Retrofitting existing repos

## Next

`/to-spec` from this plan, then `/to-tickets`.
