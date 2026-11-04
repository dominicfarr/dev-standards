# Bootstrap notes from playlist-transfer

What it actually took to set up `dominicfarr/playlist-transfer` (November 2026), from a single empty `Overview.md` to a deployed, gated, analysed app. The aim is to turn this into a reusable bootstrap skill. The notes record the **order**, **who did each step** (human or agent), the **files produced**, and every **gotcha** we hit, because most of the gotchas aren't visible in the repo itself.

Treat the files in the reference repo as the source of truth, and this doc as the "why" and "what went wrong". Nothing here is secret: the AWS account ID and policy documents are deliberately left out.

## Reference material

| What | Where |
|---|---|
| The bootstrapped repo | `/Users/dom/Projects/playlist-transfer` (GitHub `dominicfarr/playlist-transfer`, public) |
| Earlier Sonar pattern this followed | GitHub `dominicfarr/mcp-secuirty-working-notes-example`: `.github/workflows/sonar.yml` and `sonar-project.properties` |
| Claude memory for that project | `/Users/dom/.claude/projects/-Users-dom-Projects-playlist-transfer/memory/`. `user-hosting-and-tooling-preferences.md` and `feedback-dev-workflow-sequence.md` are the reusable ones. `playlist-transfer-status.md` is project-specific. |
| Decisions | `playlist-transfer/docs/adr/0002-route53-dns-and-cloudformation-per-subdomain.md` (the hosting pattern). ADR 0001 is project-specific. |
| Spec and tickets as published | GitHub issues `#1` (spec) to `#15` on `dominicfarr/playlist-transfer`. The comments on `#1`, `#4` and `#15` record corrections made along the way. |

Files in the reference repo that make up the bootstrap (everything else is the app):

```
CLAUDE.md                      CONTRIBUTING.md            README.md (Development setup)
docs/agents/{issue-tracker,triage-labels,domain}.md       GLOSSARY.md  docs/adr/
.gitignore  .prettierrc.json  .prettierignore  eslint.config.js  commitlint.config.js
.pre-commit-config.yaml        package.json (scripts)     vite.config.ts (test + coverage)
.github/workflows/ci.yml       .github/workflows/sonar.yml   .github/dependabot.yml
sonar-project.properties       infra/template.yml   infra/smoke.sh   infra/viewer-request.test.ts
```

## Developer preferences (from memory, all confirmed)

- **Hosting:** each project is `<name>.domfarr.com`: a private S3 bucket behind CloudFront with an ACM certificate in us-east-1. DNS is in **Route 53**; GoDaddy is only the registrar. Each app is **one CloudFormation stack**, deployed by **GitHub Actions through OIDC** (no long-lived AWS keys). AWS is preferred over Vercel.
- **Delivery:** follows minimumcd.org.
  - Trunk-based, working on `main`.
  - CI runs on every push, and the checks gate the deploy.
  - Only the pipeline deploys, from one build artifact.
- **Local gates:** the **pre-commit framework** with `repo: local` hooks that use the project's lockfile. Quick static checks, and any failure or modified file stops the commit.
- **Commits:** a `CONTRIBUTING.md` defines Conventional Commits 1.0.0 with project-specific scopes, so agents write consistent history. commitlint enforces it at the `commit-msg` stage.
- **External analysis:** SonarQube Cloud in its own workflow, with every action pinned to a commit SHA.
- **Stack familiarity:** Svelte rather than React. This repo uses Svelte 5, Vite and TypeScript, built as a static single-page app.
- **Workflow:** the mattpocock skills, in a fixed order: `grill-with-docs` → `to-spec` → `to-tickets` → `implement` (or `implement-spec`) → `code-review` → `retro`. Dom runs the later-stage skills themselves (they're `disable-model-invocation`). Design briefs are `PLAN.md`.
- **License:** none by default, which means all rights reserved. Dom chose that deliberately for this repo.

## The bootstrap, in order

Each phase lists **who** did it: **H** is the human only, **A** is an agent, and **A+H** is an agent with a human approval step.

### Phase 0: Process scaffolding (A)

1. `grill-with-docs` turns the idea into a `PLAN.md`, a `GLOSSARY.md` and the first ADRs.
2. `setup-matt-pocock-skills` writes `CLAUDE.md` (a "Read first" line plus the `## Agent skills` block), `docs/agents/issue-tracker.md` (GitHub), `triage-labels.md` and `domain.md`, and creates the triage labels in the repo (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`; `wontfix` already exists).
3. `CONTRIBUTING.md`: the workflow, the Conventional Commits types table, scopes taken from the glossary, examples, and "change commitlint.config.js and this file together".
4. `.gitignore` for the stack. Include `.claude/` (agent worktrees), secrets (`*.p8`, `*.pem`, `*.key`, `.env*`) and local working files.

### Phase 1: Domain DNS (once per domain, already done for domfarr.com) (A+H)

- **A:** the agent created the Route 53 hosted zone and imported every record from the GoDaddy zone export as a change-batch JSON. Then it diffed every record set by querying both nameservers (`dig` against Route 53 and against GoDaddy).
- **H:** Dom switched the nameservers at GoDaddy and sent a test email through ImprovMX forwarding.
- **Checks first:** DNSSEC must be off, or the switch breaks resolution. Drop the GoDaddy-only `_domainconnect` record. Keep every existing ACM validation CNAME, or the existing apps' certificates silently fail to renew.
- **Result:** zone `Z03722621B6AEUR5NOSKX`. **Every future project reuses it.** A new project stack only adds its own records.

### Phase 2: Repo skeleton and local gates (A)

1. **Scaffold:** generate the Vite `svelte-ts` template in a scratch folder, then copy only its config files (`svelte.config.js`, `tsconfig*.json`, `vite.config.ts`, `index.html`) and write a placeholder page. Don't copy the demo assets.
2. **Dev dependencies:** ESLint with `typescript-eslint` (strict) and `eslint-plugin-svelte`, Prettier with `prettier-plugin-svelte` and `eslint-config-prettier`, Vitest, `@commitlint/cli` with `config-conventional`, and later `@vitest/coverage-v8`.
3. **`package.json` scripts:**
   - `check` (svelte-check plus tsc for the node config)
   - `lint`, `format`, `test`
   - `test:coverage` (kept separate so `npm test` stays fast)
   - `hooks:install` (`pre-commit install --install-hooks`)
   - `engines.node >= 22`
4. **`.pre-commit-config.yaml`:**
   - `default_install_hook_types: [pre-commit, commit-msg]`
   - **Local hooks** run through `npx --no-install` so they use the lockfile: eslint `--fix --max-warnings=0`, prettier `--write`, `npm run check` (with `pass_filenames: false`), `vitest related --run --passWithNoTests`, and commitlint `--edit` at the `commit-msg` stage.
   - **Non-npm tools** come from pinned remote repos: `gitleaks`, `actionlint`, `cfn-lint` (only for `^infra/.*\.ya?ml$`) and `shellcheck-py`. Set the revs with `pre-commit autoupdate`; don't guess them.
5. **`commitlint.config.js`:** restrict `type-enum` and `scope-enum` to CONTRIBUTING's lists, with `header-max-length` and `body-max-line-length` at 72. Keep config-conventional's default `subject-case`. Overriding it with `lower-case` would reject proper nouns like "CloudFront".
6. **README "Development setup":** the prerequisites are Node 22+, uv, `uv tool install pre-commit==4.7.0`, and shellcheck (`brew install shellcheck` or `uv tool install shellcheck-py`). Then `npm ci`, `npm run hooks:install`, `npm run dev`.
7. **Prove the gates.** In a throwaway copy of the repo (rsync it and symlink `node_modules`), show that each of these commits is rejected:
   - a lint error
   - a type error
   - a failing related test
   - a staged fake secret, caught by gitleaks **alone**, so make sure no lint error is present too
   - a non-conventional message
   - an unknown scope

   Then show that a good commit passes.

### Phase 3: CI (A)

`ci.yml` runs on `push` to every branch. Other branches are only for throwaway experiments.

1. checkout with `fetch-depth: 0`
2. setup-node (from `package.json`), then `npm ci --ignore-scripts`
3. setup-uv, `uv tool install --no-build pre-commit==<pinned>`, and a cache of `~/.cache/pre-commit`
4. `pre-commit run --all-files --show-diff-on-failure`
5. commitlint over the commits in this push (see below)
6. `npm test`, `npm run build`, then upload `dist` as an artifact

**Linting the pushed commits:**
- **Normal push:** lint the range `before..sha`.
- **New branch:** lint from `merge-base origin/main` to the head, otherwise a bad commit hidden under a good one passes.
- **First push of main:** use `--last`.

To verify this, push a throwaway branch with a bad commit *underneath* a good one (`--no-verify` only for that one commit), watch it fail, then delete the branch.

### Phase 4: AWS deploy identity (once per repo) (H, with a policy the agent drafts)

- **The GitHub OIDC identity provider already exists** in the account. **Don't recreate it.**
- **One IAM role per repo**, e.g. `<app>-deploy`, with:
  - **Trust:** `aud = sts.amazonaws.com` and `sub` limited to the `main` branch, using the **immutable subject format** (see the gotchas).
  - **Inline permissions:**
    - `cloudformation:*` on that stack only
    - `s3:*` on that bucket only
    - CloudFront and ACM actions account-wide, because creating them can't be resource-scoped. This includes `Create/Update/Publish/Delete/DescribeFunction` and `Create/Update/DeleteOriginAccessControl` if the stack uses those.
    - Route 53 `ChangeResourceRecordSets` on the zone, with the `route53:ChangeResourceRecordSetsNormalizedRecordNames` condition limited to `<app>.domfarr.com` and `*.<app>.domfarr.com`.
- **Process:**
  - The agent drafts the trust and permission JSON in a scratch folder.
  - The agent validates it with `aws accessanalyzer validate-policy`.
  - Dom runs `aws iam create-role` and `put-role-policy` themselves.
- **The role ARN** goes in repo secret `AWS_DEPLOY_ROLE_ARN`. Use `gh secret set … --repo <owner>/<repo>`. Without `--repo` it lands on whichever repo matches the current folder.
- **Keep it private:** never commit or post the account ID or the policy documents in a public repo or issue. The Claude Code safety check blocks an issue comment that would.

### Phase 5: Infrastructure stack and deploy (A, the first deploy is watched)

**`infra/template.yml`** is one stack. It takes the hosted zone ID as a parameter. Its resources are tagged `app=<app>`, apart from types that can't take tags. It contains:
- a private S3 bucket: block public access, SSE, deny insecure transport, `DeletionPolicy: Retain`
- its own Origin Access Control (don't reuse the hand-made shared one)
- a DNS-validated ACM certificate
- CloudFront: `PriceClass_100`, http2and3, and a CloudFront Function for SPA fallback
- Route 53 A and AAAA alias records

**The `deploy` job** in `ci.yml`:
- `needs: checks`, and only runs on `main`, with `permissions: id-token: write`
- **no `environment:`**: it changes the OIDC subject
- steps:
  1. `aws cloudformation deploy --no-fail-on-empty-changeset`
  2. read the stack outputs
  3. `s3 sync` with immutable cache headers for `assets/` and `no-cache` for everything else
  4. a CloudFront invalidation, then wait
  5. `infra/smoke.sh`

**The first deploy** takes about 15–30 minutes (allow a job timeout of 60). If it rolls back, the retained bucket blocks the next attempt until someone deletes it by hand.

**After the deploy, check by hand:**
- the site serves over HTTPS, and HTTP redirects with a 301
- unknown routes fall back to the SPA index
- the bucket refuses direct access (403)
- the certificate is right
- **every other subdomain and the apex domain still return 200**

### Phase 6: SonarQube Cloud (H setup, then A)

**H:**
1. Import the repo into organization `dominicfarr`. The project key comes out as `dominicfarr_<repo>`.
2. **Turn off Automatic Analysis.**
3. Create a **Project Analysis Token** (scoped to the one project) and set it as `SONAR_TOKEN`, using `gh secret set`, which prompts for the value. Never paste the token into chat.

**A:**
- **`sonar.yml`:** its own workflow, run on push to `main` only (trunk-based), with:
  - `contents: read`
  - checkout with `fetch-depth: 0`
  - `npm ci --ignore-scripts`
  - `npm run test:coverage`
  - the pinned `SonarSource/sonarqube-scan-action`
- **`sonar-project.properties`:**
  - sources: `src`, `infra` and `.github`
  - tests: `src` and `infra`, with test inclusions `**/*.test.ts` and `**/*.live.ts`
  - **test files also listed in `sonar.exclusions`**, because sources and tests overlap and a file can't be indexed twice
  - `sonar.javascript.lcov.reportPaths`
  - `sonar.coverage.exclusions` matching Vitest's `coverage.exclude` (the UI and the real adapters, which aren't unit-tested by design)
  - `sonar.qualitygate.wait=true`
- **Pin every action in every workflow** to a commit SHA, with the version as a comment (Sonar S7637). Pin the existing workflows at the latest release *within their current major version*, and let Dependabot do the upgrades, so you don't mix two changes. Use the same versions in all workflows.
- **First-analysis triage.** The gate only judges *new* code, so check the whole project through the public API (`/api/qualitygates/project_status`, `/api/measures/component`, `/api/issues/search`, `/api/hotspots/search`). Fix the real issues. Record a reviewed false positive as a scoped `sonar.issue.ignore.multicriteria` entry with a comment explaining why, after the human approves it.

**What the first analysis found here, and how each was resolved:**

| Rule | What it flagged | Fix |
|---|---|---|
| S7727 | `.map(fn)` passing the function directly | call it with an explicit lambda |
| S7758 | `fromCharCode` | use `fromCodePoint` |
| S1940 | a negated comparison | rewrite without the negation |
| S2699 | a test with no assertion | add an assertion |
| S7679 | `$1` used directly in a workflow shell script | assign it to a `local` first |
| S8544 / S8541 | pre-commit installed without a pinned version, or from source | pin the version and use `--no-build` |
| S6258 / S6252 | no S3/CloudFront logs, no S3 versioning | approved as scoped ignores: logs would store visitors' IPs, and the bucket is rebuilt from git |

### Phase 7: Dependabot (A)

`.github/dependabot.yml` sets weekly, grouped updates for `npm` (prefix `build`, include scope) and `github-actions` (prefix `ci`). Dependabot's commit bodies have long lines, so `commitlint.config.js` needs an `ignores` function matching `Signed-off-by: dependabot[bot]`. If GitHub's automatic security fixes are on, Dependabot may keep failing with `security_update_not_possible` for development-only advisories. That's noise, not risk.

### Phase 8: Repo metadata (A drafts, H applies)

`gh repo edit --description … --homepage https://<app>.domfarr.com --add-topic …`, with at most 20 topics. No license unless Dom chooses one.

## Who does what

| Step | Human only | Why |
|---|---|---|
| Change nameservers at the registrar, test email | ✅ | registrar console, 2FA |
| Create or update IAM roles and policies | ✅ (agent drafts and validates) | privilege boundary; Dom approves each change |
| Set repo secrets (`AWS_DEPLOY_ROLE_ARN`, `SONAR_TOKEN`, later the Apple keys) | ✅ | secret values shouldn't pass through the agent |
| SonarQube Cloud import, Automatic Analysis off, token | ✅ | Sonar UI, account auth |
| Paid memberships (e.g. Apple Developer) | ✅ | payment, ID verification |
| Browser check of the live UI | ✅ | the agent had no browser |
| Everything else: scaffold, hooks, CI, the stack template, the Sonar workflow, triage, docs, tickets | agent | the agent asks before pushes that deploy, and before any IAM change |

## Gotchas (each one cost a red run or a retry)

1. **Immutable OIDC subject.** Dom's repos use GitHub's immutable subject, so the trust `sub` must be `repo:dominicfarr@95550/<repo>@<repo-id>:ref:refs/heads/main`. Read the prefix with `gh api repos/dominicfarr/<repo>/actions/oidc/customization/sub` (field `sub_claim_prefix`). The name-only form fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
2. **actionlint skips shellcheck when it isn't on PATH.** The hooks passed locally while CI failed (SC2129). Make shellcheck a documented prerequisite *and* add a `shellcheck-py` hook for `*.sh` files.
3. **IAM gap analysis by the implementer was wrong.** The agent listed gaps that the policy already covered and missed the real ones (CloudFront Functions and OAC actions). Check the template's resource types against the role's live policy (`aws iam get-role-policy`) before the first deploy.
4. **zsh doesn't split unquoted `$VAR` into words.** Multi-file commands and `set -e` behaved differently from bash and produced partial commits. Put multi-step git scripts in a bash script file (`set -euo pipefail`, arrays) and run that.
5. **The commitlint body limit is 72 characters.** One long body line made a commit fail, and its staged files were swept into the next commit. After any scripted commit sequence, check what each commit contains (`git show --stat`).
6. **macOS bash is 3.2**, so there are no associative arrays. Use plain variables or `eval`.
7. **`gh secret set` without `--repo`** targets whichever repo matches the current folder.
8. **A `gh run list` on a commit also lists Dependabot runs.** Filter by workflow name, or the watch will pick the wrong run.
9. **Sonar's Automatic Analysis** runs on import without `npm install` and warns that it can't resolve the tsconfig. CI-based analysis resolves it, and refuses to run while Automatic Analysis is on.
10. **The context-mode plugin blocks `curl`.** Use its `ctx_execute` with `fetch` for HTTP API checks.
11. **`npm audit` reports development-only advisories** (minimatch through ESLint) whose "fixes" are major downgrades. Note them; don't apply them.
12. **Wrong Conventional Commit *types* aren't caught by tooling** (`fix` for a CI-only change, `feat` for a test helper). commitlint only checks the type is in the allowed list. A review step catches it, so put the rule ("`feat`/`fix` only for user-visible changes") in front of agents.
13. **Implementer agents in worktrees** need `npm ci` in each worktree. The git hooks are shared from the main `.git`. The merger has to rebase onto the new `main` when tickets run in parallel.

## Generic versus project-specific

**Generic, so part of the bootstrap:**
- phases 0 and 2–8
- the Route 53 reuse from phase 1
- the hosting pattern in ADR 0002
- CloudFront with an S3 origin, the SPA fallback and the smoke check
- the setup for coverage, Sonar and Dependabot

**Specific to playlist-transfer, so not part of the bootstrap:**
- the second CloudFront origin to `open.spotify.com` for `/embed/playlist/*`, and its 404 rule in the viewer function
- the live Source Playlist check workflow
- the Spotify embed fixtures
- ADR 0001
- the Apple MusicKit token work (#7, not built yet)

**In between:**
- `infra/viewer-request.test.ts`: the routing function is generic, but its embed rule isn't.
- The `domfarr.com` zone ID and the `dominicfarr` organization: constants for Dom, but parameters for anyone else.

## Questions for the skill design (to work through in PLAN.md)

- **Scope:** one skill for the whole bootstrap, or one per phase (DNS, repo gates, CI, AWS role, stack, Sonar), each runnable on its own and able to resume?
- **Generation:** generate the files from templates (copied from playlist-transfer), or guide an agent through writing them?
- **What varies:** stack (Svelte/Vite/TS only, or other frontends and Python, as in the earlier Sonar repo), domain, organization, and whether there's a backend or Lambda.
- **Human steps:** how the skill hands them over. A checklist, or the `mattpocock-skills:wizard` interactive bash wizard? And how it waits for and verifies them (e.g. `gh secret list`, `aws iam get-role`).
- **Verification:** how the "prove the gates reject bad commits" step and the first-deploy checks become repeatable scripts.
- **Upkeep:** how the pinned versions (pre-commit, actions, scan action) stay current across projects.
