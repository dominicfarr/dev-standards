# Development practices

Every **standard** a **project** follows. Grilling reads this as settled scope: treat each standard as decided, and ask only about choices it leaves open (which **stack**, the domain, hosting). A project that departs from a standard records why in an ADR.

Each section says **when** it applies and which **tickets** it implies. The triggers are:

- **At creation:** `new-project` sets it up. No ticket, unless it's missing.
- **Once `PLAN.md` exists:** after the first grilling.
- **When a stack is chosen:** per stack, Python or JS/TS (Svelte).
- **Once code with tests exists:** the first tested code is on `main`.

Terms in bold are defined in the standards repo's [GLOSSARY.md](https://github.com/dominicfarr/dev-standards/blob/main/GLOSSARY.md).

## Tickets by trigger

| Trigger | Ticket | Label | Section |
|---|---|---|---|
| Once `PLAN.md` exists | Repo metadata: About description and topics, drafted for Dom to apply | `ready-for-human` | [Repo metadata](#repo-metadata) |
| When a stack is chosen | Add the `<stack>` stack, one ticket per stack | `ready-for-agent` | [Stacks](#stacks) |
| Once code with tests exists | Sonar human steps | `ready-for-human` | [Sonar](#sonar) |
| Once code with tests exists | Add Sonar, blocked by the human steps | `ready-for-agent` | [Sonar](#sonar) |

Hosting and deploy tickets come from the project's own grilling; this document doesn't cover them yet.

## Delivery

**When:** at creation. **Tickets:** none.

- **Trunk-based** on `main`: small, working commits straight to `main`. Other branches are throwaway experiments.
- **[minimumcd.org](https://minimumcd.org):** CI runs on every push to every branch, the checks gate the deploy, only the pipeline deploys, and it deploys the one build artifact CI produced.
- The base CI (`.github/workflows/ci.yml`, copied at creation) runs pre-commit across all files and lints every commit in the push. It has two marked **extension points**: toolchain and install, before pre-commit, and test, build and upload, after the checks.
- A deploy job, when hosting arrives, `needs` the checks, runs only on `main` and deploys the uploaded artifact.

## Local gates

**When:** at creation. **Tickets:** none; each stack ticket extends them.

- The **base gates** are gitleaks, actionlint, shellcheck-py and commitlint at the `commit-msg` stage, in `.pre-commit-config.yaml`. commitlint runs through pre-commit, so a project needs no npm to lint commits. Its types and scopes match `CONTRIBUTING.md`; change both together.
- pre-commit is installed with `uv tool install pre-commit==<pin>`, and CI installs the same pin. Bump both together.
- `pre-commit install --install-hooks` installs both the `pre-commit` and `commit-msg` hooks.
- A hook that fails or changes files stops the commit. Fix the cause, `git add -u`, commit again. Every commit goes through the hooks; `--no-verify` is never used.
- Hook revs come from `pre-commit autoupdate`.
- [`scripts/gate-proof.sh`](https://github.com/dominicfarr/dev-standards/blob/main/scripts/gate-proof.sh) in the standards repo re-proves the gates after any change to them. Run it from a standards repo checkout with the project's path: `scripts/gate-proof.sh <project-dir>`. With no argument it proves the standards repo itself, which has no stack, against the hook fragments' fixtures.

## Stacks

**When:** a stack is chosen. **Tickets:** one "Add the `<stack>` stack" ticket per stack (`ready-for-agent`).

| Stack | Package manager | **Hook fragment** | Dependabot ecosystem |
|---|---|---|---|
| Python | uv | [`hooks/python.yaml`](https://github.com/dominicfarr/dev-standards/blob/main/hooks/python.yaml): ruff, pyright, pytest via `uv run --locked` | `uv` |
| JS/TS (Svelte) | npm | [`hooks/js-ts.yaml`](https://github.com/dominicfarr/dev-standards/blob/main/hooks/js-ts.yaml): eslint, prettier, svelte-check, related vitest via `npx --no-install` | `npm` |

Hook fragments live in the standards repo. They are `repo: local` hooks that run the project's tools from its own lockfile ([ADR 0001](https://github.com/dominicfarr/dev-standards/blob/main/docs/adr/0001-projects-copy-standards.md)).

**JS/TS (Svelte) notes:**

- **svelte-kit sync:** a SvelteKit project runs `npx --no-install svelte-kit sync` right after `npm ci --ignore-scripts` in CI, because the skipped `prepare` script would have done it. It generates `.svelte-kit/`, which the project's `tsconfig.json` extends, so without it svelte-check and the type check fail. The base CI's install extension point comment says so too.
- **.prettierignore:** the project's `.prettierignore` lists every file copied from the standards repo with a source header, using the lines in the comment at the top of `hooks/js-ts.yaml`. The prettier hook runs on every text file, and the copies then diff cleanly against upstream whatever the project's prettier style.
- **TypeScript:** pin it to the 6.x the fixture (`scripts/fixtures/js-ts`) is proven on, until svelte-check and typescript-eslint support 7. Dependabot will propose 7 as a major upgrade; hold it until the fixture is moved to 7 and the gate proof passes on it.

A stack ticket is done when all of these hold:

1. **Toolchain:** the project's lockfile (`uv.lock` or `package-lock.json`) holds the tools its hook fragment runs, as dev dependencies.
2. **Hooks:** the hook fragment is merged into `.pre-commit-config.yaml` with a **source header** and its `<sha>` filled in, then proven with the standards repo's gate proof, run from a checkout of it against the project: `scripts/gate-proof.sh <project-dir>`. It works in a throwaway copy, never in the project itself, installs the copy from the lockfile (`npm ci`, so a SvelteKit `prepare` runs `svelte-kit sync`; or `uv sync --locked`), re-proves the base gates there, and for an npm project commits a lint error, a type error and a failing related test (a break in an existing tested module) in turn, each formatted by the project's own prettier. Each must be rejected by its own hook alone, and a good commit with a test accepted. It deletes the copy afterwards; no hand-written proof script is needed. A project with no tests yet fails the related-test case. There are no project cases for a `uv.lock` project yet: it gets the install and the base gates, so add Python project cases to the gate proof when the first Python project needs them.
3. **CI:** the base CI's two **extension points**. _Toolchain and install_, before pre-commit: set up the toolchain and install without running scripts (`npm ci --ignore-scripts`; `uv sync --locked --no-build`, Sonar S8541). It comes before pre-commit because the stack's hooks run the project's own installed tools. _Test, build, upload_, after the checks: run the tests, build once and upload the build as an artifact.
4. **Dependabot:** `.github/dependabot.yml` gains the stack's ecosystem, weekly and grouped, with commit prefix `build` and `include: scope`, giving `build(deps): …`.
5. **README:** the *Development setup* section gains the stack's prerequisites and install command.

Folder layout for a project with both stacks is undecided; grill it when it comes up.

## Pinning

**When:** at creation, and on every new workflow or action. **Tickets:** none; each workflow ticket follows it.

- Every action is pinned to a commit SHA, with the version as a comment: `uses: actions/checkout@<sha> # v5.0.0`. Sonar flags unpinned actions (S7637).
- Pin at the latest release within the action's current major version. Use the same version in every workflow.
- Dependabot (`github-actions`, weekly, grouped, prefix `ci`, from creation) proposes major upgrades as separate changes.
- Install exact versions (S8544) without build or install scripts (S8541): `--no-build`, `--ignore-scripts`.

## Sonar

**When:** once code with tests exists. **Tickets:** "Sonar human steps" (`ready-for-human`), then "Add Sonar" (`ready-for-agent`, blocked by the human ticket).

**Human steps,** about two minutes:

1. Import the repo into the SonarQube Cloud organization `dominicfarr`. The project key comes out as `dominicfarr_<repo>`.
2. Turn Automatic Analysis off.
3. Create a Project Analysis Token for the project.
4. `gh secret set SONAR_TOKEN --repo dominicfarr/<repo>`, typing the token at the prompt.

**The agent ticket** is done when all of these hold:

1. **Human steps checked:** `gh secret list --repo dominicfarr/<repo>` lists `SONAR_TOKEN`, and Sonar's public `/api/qualitygates/project_status?projectKey=dominicfarr_<repo>` finds the project. If either fails, stop and report.
2. **Templates copied** with source headers (the `<sha>` in each file's first line set to the commit read): [`templates/sonar.yml`](https://github.com/dominicfarr/dev-standards/blob/main/templates/sonar.yml) to `.github/workflows/sonar.yml`, and [`templates/sonar-project.properties`](https://github.com/dominicfarr/dev-standards/blob/main/templates/sonar-project.properties) to the root, with `<repo>` replaced. The workflow is its own workflow, on push to `main`, so a red gate never shows as failing tests.
3. **Coverage extension points filled:** each is marked `EXTENSION POINT` in the templates. The stack's install and test-under-coverage steps in the workflow, at the base CI's action versions; the coverage report path and `sonar.coverage.exclusions` in the properties, matching the test tool's own excludes. Tests next to the code are also listed in `sonar.exclusions`, since a file can't be indexed twice. A repo with no tests (such as this one) deletes the workflow's extension point, drops `sonar.tests`, sets no report path and sets `sonar.coverage.exclusions=**/*`, so there is nothing to cover and the gate can't fail on missing coverage.
4. **First-analysis triage:** the gate judges only new code, so the agent checks the whole project through `/api/measures/component`, `/api/issues/search` and `/api/hotspots/search`. It fixes real issues in code. A reviewed false positive becomes a scoped `sonar.issue.ignore.multicriteria` entry with a comment saying why, added only after Dom approves it. The target is a passing gate, zero bugs, vulnerabilities, code smells and hotspots, and all ratings A.
5. **Badges:** quality gate and coverage badges in the README, with one line on what Sonar checks. A repo with no tests shows no coverage badge.

A red quality gate counts as a red build.

## Repo metadata

**When:** the About description and topics once `PLAN.md` exists; each badge with the thing it reports. **Tickets:** "Repo metadata" (`ready-for-human`) once `PLAN.md` exists; the badges ride on other work.

- **About:** the agent creating the ticket drafts it; Dom applies it. The ticket body holds the drafted description and topics (at most 20, drawn from `PLAN.md` and the glossary) as one ready-to-run command, `gh repo edit dominicfarr/<repo> --description … --add-topic …`. Agents never run `gh repo edit` themselves. Add `--homepage` once hosting exists, in a new draft.
- **CI badge:** with the base CI, at creation.
- **Quality gate and coverage badges:** in the "Add Sonar" ticket; no coverage badge without tests.

## Secrets

**When:** whenever a workflow needs one. **Tickets:** a `ready-for-human` ticket, or a human step inside the ticket that needs it.

- Only Dom sets secrets, with `gh secret set NAME --repo <owner>/<repo>`, which prompts for the value. Always pass `--repo`.
- Values stay out of agents, chat, issues and commits. An agent checks a secret exists with `gh secret list --repo <owner>/<repo>`.

## License

**When:** at creation. **Tickets:** none.

No license by default, which means all rights reserved. A license is Dom's decision.

## Gotchas

**When:** always. **Tickets:** none. Each of these cost a red run or a retry.

1. **actionlint skips shellcheck when shellcheck isn't on PATH**, so hooks pass locally and CI fails. shellcheck is a documented prerequisite, and the base gates include `shellcheck-py`.
2. **Keep config-conventional's default `subject-case`.** Overriding it with `lower-case` rejects proper nouns ("CloudFront").
3. **The 72-character body-line limit is enforced.** A failed scripted commit leaves its files staged, and the next commit sweeps them up. After any scripted commit sequence, check each commit with `git show --stat`.
4. **Tooling only checks that a commit type is allowed, not that it's right.** `feat` and `fix` are only for changes the person using the project can see; review catches the rest.
5. **zsh doesn't split unquoted `$VAR`, and macOS ships bash 3.2** with no associative arrays. Write multi-step git or gh scripts as bash files with `set -euo pipefail` and plain arrays.
6. **`gh secret set` without `--repo`** targets whichever repo matches the current folder.
7. **`gh run list --commit` also lists Dependabot runs.** Filter by workflow name before watching a run.
8. **Sonar's Automatic Analysis** runs on import without installing dependencies, reports unresolvable configs, and blocks CI-based analysis. Turn it off before the first CI scan.
9. **GitHub's automatic security fixes** can fail repeatedly with `security_update_not_possible` for development-only advisories. That's noise, not risk. Likewise, `npm audit` "fixes" for development-only advisories that are major downgrades get noted, not applied.
10. **On Dom's machine, the context-mode plugin blocks `curl`.** This comes from Dom's agent setup, not from any project. There, make HTTP API checks, such as Sonar's API, through `ctx_execute` with `fetch`.
11. **Agent worktrees** need the stack's install (`uv sync`, `npm ci`) in each worktree; the git hooks are shared from the main `.git`. When tickets run in parallel, the merger rebases onto the new `main`.
12. **Commits made in GitHub's web editor skip the local hooks.** Its default message ("Update README.md") fails commit-lint, so `main` goes red in CI. Make commits locally. If one slips through and is still the tip of `main`, amend the message and `git push --force-with-lease`, only with Dom's OK.
