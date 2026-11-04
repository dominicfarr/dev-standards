#!/usr/bin/env bash
# Gate proof: shows the base gates reject bad commits and accept a good one.
#
# Usage: scripts/gate-proof.sh [repo-dir]
#
# Copies repo-dir (default: the repo holding this script) into a throwaway
# git repo, installs its pre-commit hooks there and tries each case. Nothing
# in repo-dir is changed. Exits non-zero if any case fails.
#
# To add a case (for example a hook fragment's lint error), write a
# case_<name> function below that stages a change and calls expect_rejected
# or expect_accepted, then add it to CASES. Use a fresh throwaway with
# make_throwaway if the case needs a different project.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source_repo=$(cd "${1:-$script_dir/..}" && git rev-parse --show-toplevel)

workdir=$(mktemp -d "${TMPDIR:-/tmp}/gate-proof.XXXXXX")
trap 'rm -rf "$workdir"' EXIT

passed=0
failed=0
log="$workdir/last-commit.log"

pass() { passed=$((passed + 1)); printf 'PASS  %s\n' "$1"; }
fail() {
  failed=$((failed + 1))
  printf 'FAIL  %s\n' "$1"
  sed 's/^/      | /' "$log"
}

# make_throwaway <name>: copies source_repo's tracked and untracked
# (non-ignored) files into $workdir/<name>, commits them as a baseline before
# any hook exists, then installs the hooks. Leaves you in the new repo.
make_throwaway() {
  local dest="$workdir/$1"
  mkdir -p "$dest"
  (cd "$source_repo" && git ls-files -z -co --exclude-standard |
    tar -cf - --null -T -) | tar -xf - -C "$dest"
  cd "$dest"
  git init -q -b main
  git config user.name "Gate Proof"
  git config user.email "gate-proof@example.invalid"
  git config commit.gpgsign false
  git add -A
  git commit -q -m "chore: baseline"
  pre-commit install --install-hooks >"$log" 2>&1 || {
    fail "pre-commit install in throwaway copy"
    exit 1
  }
}

# commit_with <message>: commits what's staged through the hooks.
commit_with() {
  git commit -q -m "$1" >"$log" 2>&1
}

# expect_rejected <description> <message> <hook name> [<expected output>]
# Passes when the commit fails, <hook name> is the only hook that failed, and
# its output contains <expected output> (a fixed string), if given.
expect_rejected() {
  local description=$1 message=$2 only_hook=$3 expected=${4:-}
  local before after
  before=$(git rev-parse HEAD)
  if commit_with "$message"; then
    fail "$description (commit was accepted)"
  else
    after=$(git rev-parse HEAD)
    if [ "$before" != "$after" ]; then
      fail "$description (HEAD moved)"
    elif ! only_failure_is "$only_hook"; then
      fail "$description (not rejected by $only_hook alone)"
    elif [ -n "$expected" ] && ! grep -qF -- "$expected" "$log"; then
      fail "$description (output lacks: $expected)"
    else
      pass "$description"
    fi
  fi
  git reset -q --hard HEAD
  git clean -qfd
}

# expect_accepted <description> <message>
expect_accepted() {
  local description=$1 message=$2
  if commit_with "$message"; then
    pass "$description"
  else
    fail "$description (commit was rejected)"
    git reset -q --hard HEAD
    git clean -qfd
  fi
}

# only_failure_is <hook name>: true when the last commit's hook output shows
# exactly one failed hook and it is <hook name>.
only_failure_is() {
  local failures
  failures=$(grep -E '\.Failed$' "$log" || true)
  [ "$(printf '%s\n' "$failures" | grep -c .)" -eq 1 ] &&
    printf '%s\n' "$failures" | grep -q "^$1"
}

# A token in the shape of a GitHub personal access token, built at run time
# so no secret-shaped string is ever committed in this script.
fake_github_token() {
  local body
  body=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)
  printf 'ghp_%s' "$body"
}

case_staged_secret() {
  printf 'github_token = "%s"\n' "$(fake_github_token)" >settings.txt
  git add settings.txt
  expect_rejected "staged fake secret rejected by gitleaks alone" \
    "docs: add settings" "Detect hardcoded secrets"
}

case_non_conventional_message() {
  printf 'note\n' >note.txt
  git add note.txt
  expect_rejected "non-conventional message rejected" "added a note" \
    commitlint "type may not be empty"
}

case_unknown_scope() {
  printf 'note\n' >note.txt
  git add note.txt
  expect_rejected "unknown scope rejected" "docs(nonsense): add a note" \
    commitlint "scope must be one of"
}

case_good_commit() {
  printf 'note\n' >note.txt
  git add note.txt
  expect_accepted "good commit accepted" "docs: add a note"
}

# Dependabot's bodies carry release notes with lines over 72 characters.
case_dependabot_commit() {
  local long_line
  long_line=$(printf 'Release notes line %.0s' 1 2 3 4 5)
  printf 'bump\n' >dependabot.txt
  git add dependabot.txt
  expect_accepted "Dependabot commit with long body lines accepted" \
    "$(printf '%s\n\n%s\n\n%s' \
      'ci(deps): bump actions/checkout from 4 to 5' \
      "$long_line" \
      'Signed-off-by: dependabot[bot] <support@github.com>')"
}

# --- JS/TS hook fragment ----------------------------------------------------

# make_js_ts_project: builds a scratch Svelte/TS project in $workdir/js-ts
# from scripts/fixtures/js-ts (with its npm lockfile), the base gates and
# hooks/js-ts.yaml appended unedited to the base pre-commit config. Commits a
# baseline before any hook exists, then installs the hooks. Leaves you in it.
make_js_ts_project() {
  local dest="$workdir/js-ts"
  local fragment="$source_repo/hooks/js-ts.yaml"
  mkdir -p "$dest"
  if [ ! -f "$fragment" ]; then
    printf 'missing %s\n' "$fragment" >"$log"
    return 1
  fi
  (cd "$source_repo/scripts/fixtures/js-ts" &&
    git ls-files -z -co --exclude-standard . | tar -cf - --null -T -) |
    tar -xf - -C "$dest"
  cp "$source_repo/.gitignore" "$source_repo/commitlint.config.mjs" "$dest/"
  cat "$source_repo/.pre-commit-config.yaml" "$fragment" \
    >"$dest/.pre-commit-config.yaml"
  cd "$dest"
  npm ci --ignore-scripts --no-audit --no-fund >"$log" 2>&1 || return 1
  git init -q -b main
  git config user.name "Gate Proof"
  git config user.email "gate-proof@example.invalid"
  git config commit.gpgsign false
  git add -A
  git commit -q -m "chore: baseline"
  pre-commit install --install-hooks >"$log" 2>&1
}

case_js_ts() {
  if ! make_js_ts_project; then
    fail "JS/TS scratch project with the hook fragment merged"
    cd "$workdir/base"
    return
  fi

  printf 'export function half(n: number): number {\n  const unused = 1;\n  return n / 2;\n}\n' \
    >src/half.ts
  git add src/half.ts
  expect_rejected "JS/TS lint error rejected by eslint alone" \
    "feat: add half" eslint "no-unused-vars"

  printf '<script lang="ts">\n  const label: number = "total";\n</script>\n\n<p>{label}</p>\n' \
    >src/Label.svelte
  git add src/Label.svelte
  expect_rejected "JS/TS type error rejected by svelte-check alone" \
    "feat: add label" svelte-check "not assignable to type 'number'"

  printf 'export function sum(a: number, b: number): number {\n  return a - b;\n}\n' \
    >src/sum.ts
  git add src/sum.ts
  expect_rejected "JS/TS failing related test rejected by vitest alone" \
    "fix: change sum" "vitest related" "adds two numbers"

  printf 'export function double(n: number): number {\n  return n * 2;\n}\n' \
    >src/double.ts
  printf 'import { expect, test } from "vitest";\nimport { double } from "./double";\n\ntest("doubles a number", () => {\n  expect(double(2)).toBe(4);\n});\n' \
    >src/double.test.ts
  git add src/double.ts src/double.test.ts
  expect_accepted "JS/TS good commit accepted" "feat: add double"

  cd "$workdir/base"
}

CASES="
  case_staged_secret
  case_non_conventional_message
  case_unknown_scope
  case_good_commit
  case_dependabot_commit
  case_js_ts
"

printf 'Gate proof for %s\n' "$source_repo"
make_throwaway base
for case_fn in $CASES; do
  "$case_fn"
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
