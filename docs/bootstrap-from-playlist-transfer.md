# The project archetype (from playlist-transfer)

The **project-agnostic base** every new repo starts from. It was taken from what was actually built for `dominicfarr/playlist-transfer` in November 2026, minus everything specific to that project.

The archetype is the layer that stays the same whatever gets built on top. Later skills or layers add the language, the framework, the hosting and any API or database, and they plug into the **extension points** marked below.

The full history, including the hosting, AWS and DNS details, is in [playlist-transfer-full-notes.md](playlist-transfer-full-notes.md).

## In scope versus out of scope

| The archetype provides | Later layers provide (not here) |
|---|---|
| A GitHub repo, set up for agent workflows | The language toolchain and lockfile (npm, uv, …) |
| `CLAUDE.md`, `docs/agents/`, labels | The framework and app scaffold |
| `CONTRIBUTING.md` with Conventional Commits | Lint, format, type-check and test tools |
| A language-agnostic `.gitignore` | Language entries appended to `.gitignore` |
| The pre-commit framework plus language-agnostic hooks | The language's hooks (as `repo: local`, run from its lockfile) |
| A trunk-based CI pipeline: checks, commit-message lint, slots for test and build | The test and build commands, and the deploy job |
| The SonarQube Cloud workflow and base properties | The coverage report path, and language-specific Sonar settings |
| Dependabot for GitHub Actions | Dependabot for the language's package ecosystem |
| Repo metadata, and the license decision | Hosting (subdomain, static site, container), API, database |

## 1. Repo and GitHub (agent, with secrets set by the human)

- Create the repo with **`main`** as the default branch and Issues enabled. It's public unless decided otherwise.
- Run **`setup-matt-pocock-skills`**. It creates:
  - `CLAUDE.md`: a "Read first" line pointing to `PLAN.md`, `GLOSSARY.md`, `docs/adr/` and `CONTRIBUTING.md`, then the `## Agent skills` block
  - `docs/agents/issue-tracker.md` (GitHub), `triage-labels.md` and `domain.md`
  - the labels `needs-triage`, `needs-info`, `ready-for-agent` and `ready-for-human` (`wontfix` already exists)
- **Created later, not by the archetype:** `PLAN.md`, `GLOSSARY.md` and `docs/adr/` come from `grill-with-docs` once the project is defined. The archetype only references them.
- **Metadata:** `gh repo edit --description … --add-topic …` (at most 20 topics). **No license** by default, which means all rights reserved. That's a deliberate choice.
- **Secrets:** the human sets them with `gh secret set NAME --repo <owner>/<repo>`, which prompts for the value. Values never go through the agent or the chat. **Always pass `--repo`.**

## 2. CONTRIBUTING.md (agent)

- **Workflow:**
  - Trunk-based: small, working commits directly to `main`.
  - Every commit passes the hooks, and `--no-verify` is never used.
  - Only the pipeline deploys.
  - The Sonar quality gate is a separate signal from CI, but a red gate counts as a red build.
- **One-time setup:** points to the README's *Development setup* section. The archetype lists pre-commit and shellcheck there; language layers add their own prerequisites.
- **Conventional Commits 1.0.0:**
  - **Format:** imperative, lower-case start, at most 72 characters for the header and per body line, and a body that explains *why*.
  - **Footers:** `Refs: #n`, `Co-Authored-By:`, and `BREAKING CHANGE:` together with `!`.
  - **One logical change per commit.** If the description needs "and", split the commit.
  - **Types:**

    | Type | Use for |
    |---|---|
    | `feat`, `fix` | **Only** changes the user can see |
    | `refactor`, `perf` | Code changes with no change in behaviour, and performance improvements |
    | `test` | Tests only |
    | `docs` | Documentation only |
    | `build` | Tooling, dependencies, config |
    | `ci` | Workflows and the pre-commit config |
    | `chore` | Anything else |
    | `revert` | Reverting an earlier commit |

  - **Scopes:** an **extension point**, filled from the project's glossary terms. The base set is `deps` and `adr`.
- **commitlint enforces it:** the allowed types and scopes in commitlint's config must match CONTRIBUTING, so "change both together".

## 3. .gitignore, language-agnostic base (agent)

Sections that layers append to:

- **OS:** macOS (`.DS_Store`, `._*`, `.Spotlight-V100`, …)
- **Editors and agents:** `.vscode/`, `.idea/`, `*.swp`, `*~`, and **`.claude/`**, where agent worktrees live
- **Secrets:** `.env`, `.env.*`, `!.env.example`, `*.pem`, `*.key`, `*.p8`
- **Logs:** `*.log`
- **Local working files:** a commented section for anything that must stay out of a public repo

Language layers append their own section (dependencies, build output, caches, coverage).

## 4. Pre-commit (agent)

- **Framework:** `pre-commit`, installed with `uv tool install pre-commit==<pinned>`, and the **same pin in CI**. `default_install_hook_types: [pre-commit, commit-msg]`, then `pre-commit install --install-hooks`.
- **Language-agnostic hooks** (remote repos, pinned by `rev`; set them with `pre-commit autoupdate`, never guess):
  - `gitleaks`: secret scanning on everything that's staged
  - `actionlint`: GitHub workflows (needs **shellcheck on PATH**, see the gotchas)
  - `shellcheck-py`: shell scripts
  - **a commit-message linter at the `commit-msg` stage**. playlist-transfer used npm commitlint as a local hook, because the project already had npm. *For the agnostic base, this is an open choice:* a pre-commit-managed commitlint, a Python `conventional-pre-commit`, or whatever the language layer provides.
- **Extension point:** the language layer adds `repo: local` hooks that run its tools from its lockfile (e.g. `npx --no-install …`, `uv run …`): lint `--fix`, format, type-check, related tests. Rule: **any hook that fails or modifies files stops the commit.**
- **Prove the gates once.** In a throwaway copy of the repo, show that commits are rejected for:
  - a staged fake secret, caught by gitleaks **alone**, so make sure no other hook would fail first
  - a non-conventional message
  - an unknown scope

  Then show that a good commit passes. Language layers add their own cases: lint errors, type errors, failing tests.

## 5. CI, trunk-based (agent)

`.github/workflows/ci.yml` runs `on: push`, on every branch. Other branches are only for throwaway experiments. It has `permissions: contents: read`, `concurrency` without cancel-in-progress, a timeout, and **every action pinned to a commit SHA, with the version as a comment.**

The `checks` job:
1. checkout with `fetch-depth: 0`
2. setup-uv, then `uv tool install --no-build pre-commit==<pinned>`, and a cache of `~/.cache/pre-commit` keyed on the config file
3. **Extension point (toolchain and install):** the language layer's setup and install (with `--ignore-scripts` or the equivalent). It sits before pre-commit because the language layer's hooks run the project's own installed tools.
4. `pre-commit run --all-files --show-diff-on-failure`
5. **lint every commit in the push:**
   - **normal push:** the range `before..sha`
   - **new branch:** from `merge-base origin/main` to the head
   - **first push of main:** only the last commit
6. **Extension point (test, build, upload):** the language layer's **test and build** steps. Build once, and upload the build as an artifact.

The `deploy` job is an **extension point** for the hosting layer: `needs: checks`, and runs only on `main`.

**Verify CI once:** push a throwaway branch with a bad commit *underneath* a good one (`--no-verify` only for that one commit), confirm CI fails at the commit-message step, then delete the branch.

## 6. SonarQube Cloud (human setup, then agent)

**Human:**
1. Import the repo into organization `dominicfarr`. The key comes out as `dominicfarr_<repo>`.
2. **Turn off Automatic Analysis.**
3. Create a **Project Analysis Token**, scoped to the project, and set it as `SONAR_TOKEN`.

**Agent:**
- **`.github/workflows/sonar.yml`:** its own workflow, so a gate failure never shows as failing tests. It runs on push to `main` only, with:
  - `contents: read`
  - checkout with `fetch-depth: 0`
  - **an extension point** where the language layer installs and runs its tests under coverage
  - the SHA-pinned `SonarSource/sonarqube-scan-action`, with `SONAR_TOKEN` from secrets
- **`sonar-project.properties` base:**
  - `sonar.projectKey`, `sonar.organization`
  - `sonar.sources` and `sonar.tests`. If the tests live next to the code, also list the test patterns in `sonar.exclusions`, because a file can't be indexed twice.
  - `sonar.qualitygate.wait=true`
  - **extension points** for the coverage report path and `sonar.coverage.exclusions` (keep them in step with the test tool's own excludes)
- **First-analysis triage.** The gate only judges *new* code, so also check the whole project:
  - `/api/qualitygates/project_status`, `/api/measures/component`, `/api/issues/search`, `/api/hotspots/search`
  - Fix the real issues in code.
  - Record a reviewed false positive as a scoped `sonar.issue.ignore.multicriteria` entry with a comment explaining why, **after the human approves it**.
  - Goal: the gate passes, with 0 bugs, vulnerabilities, code smells and hotspots, and all ratings A.
- **Rules that apply to any repo** (they come from the workflows themselves):
  - S7637: pin actions to SHAs
  - S8544: install exact versions
  - S8541: no build or install scripts (`--no-build`, `--ignore-scripts`)
  - S7679: assign `$1` to a local variable in workflow shell scripts

## 7. Dependabot (agent)

The `.github/dependabot.yml` base is weekly, grouped updates for **`github-actions`** (prefix `ci`). Dependabot updates the pinned SHAs too.

- **Pinning policy:** pin at the latest release *within the current major version*, and let Dependabot propose the major upgrades as separate changes.
- **Extension point:** the language layer adds its package ecosystem (prefix `build`, include scope).
- **commitlint:** Dependabot's commit bodies have long lines, so the commit-message linter must ignore commits containing `Signed-off-by: dependabot[bot]`.

## 8. README (agent)

The README gets:
- badges for CI, the quality gate and coverage
- one line on what Sonar checks
- **Development setup**: pre-commit (pinned version), shellcheck (`brew install shellcheck` or `uv tool install shellcheck-py`) and `hooks:install`, plus whatever the language layer adds

## Who does what

| Human only | Agent |
|---|---|
| Set secrets (`gh secret set`, value typed at the prompt) | Everything in sections 1–8 |
| SonarQube Cloud import, Automatic Analysis off, project token | First-analysis triage, proposing scoped ignores |
| Approving reviewed false positives and any pushes outside the normal flow | Proving the gates and CI with throwaway copies and branches |
| The license decision | Drafting repo metadata |

## Gotchas that apply to any project

1. **actionlint skips shellcheck when shellcheck isn't on PATH.** Hooks pass locally and CI fails. Make shellcheck a documented prerequisite, and add the `shellcheck-py` hook.
2. **Don't override commitlint's `subject-case` with `lower-case`.** It rejects proper nouns ("CloudFront"). Keep config-conventional's default.
3. **The 72-character body limit is enforced.** A failed scripted commit leaves its files staged, and they get swept into the next commit. After any scripted commit sequence, check what each commit contains (`git show --stat`).
4. **Tooling doesn't catch wrong commit *types*** (e.g. `fix` for a CI-only change). commitlint only checks the type is in the allowed list. The code-review step has to catch it, so give agents the "`feat`/`fix` only for user-visible changes" rule up front.
5. **zsh doesn't split unquoted `$VAR` into words**, and macOS ships **bash 3.2**, which has no associative arrays. Write multi-step git or gh scripts as bash script files with `set -euo pipefail` and arrays.
6. **`gh secret set` without `--repo`** targets whichever repo matches the current folder.
7. **`gh run list --commit` also lists Dependabot runs.** Filter by workflow name before watching a run.
8. **Sonar's Automatic Analysis** runs on import without installing dependencies, so it reports unresolvable configs. It also stops CI-based analysis from running. Turn it off before the first CI scan.
9. **GitHub's automatic security fixes** can fail repeatedly (`security_update_not_possible`) for development-only advisories. That's noise, not risk.
10. **The context-mode plugin blocks `curl`**, so HTTP API checks (e.g. Sonar's API) go through `ctx_execute` with `fetch`.
11. **Agent worktrees** need the language layer's install in each worktree. The git hooks are shared from the main `.git`.

## Open questions for PLAN.md

- **The commit-message linter in a language-agnostic base:** pre-commit-managed commitlint, `conventional-pre-commit`, or delegate it to the language layer?
- **Generic hooks:** should the base also include the `pre-commit-hooks` basics (end-of-file, trailing whitespace, check-yaml, merge conflicts, large files)? playlist-transfer didn't use them.
- **Markdown and YAML formatting:** playlist-transfer formatted docs with Prettier, an npm tool. What does a language-agnostic base use, if anything?
- **How layers attach:** how the language and hosting layers fill the extension points. Templates with marked slots, or skills that edit known sections?
- **Human steps:** how the skill hands them over and then verifies them (`gh secret list`, Sonar's API). A checklist, or `mattpocock-skills:wizard`?
- **Upkeep:** how the pinned versions (pre-commit, actions, the scan action) stay current across all projects using the archetype.
