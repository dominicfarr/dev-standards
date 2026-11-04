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
# or expect_accepted, then add it to the cases array. Use a fresh throwaway
# with make_throwaway if the case needs a different project.
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

# make_throwaway <name> [<setup function>]: copies source_repo's tracked and
# untracked (non-ignored) files into $workdir/<name>, runs <setup function>
# there if given (to lay down a scratch project), commits it all as a
# baseline before any hook exists, then installs the hooks. Leaves you in
# the new repo.
make_throwaway() {
  local dest="$workdir/$1"
  mkdir -p "$dest"
  (cd "$source_repo" && git ls-files -z -co --exclude-standard |
    tar -cf - --null -T -) | tar -xf - -C "$dest"
  cd "$dest"
  local setup=${2:-}
  if [[ -n "$setup" ]]; then
    "$setup" >"$log" 2>&1 || {
      fail "$setup in throwaway copy"
      exit 1
    }
  fi
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
  local message=$1
  git commit -q -m "$message" >"$log" 2>&1
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
    if [[ "$before" != "$after" ]]; then
      fail "$description (HEAD moved)"
    elif ! only_failure_is "$only_hook"; then
      fail "$description (not rejected by $only_hook alone)"
    elif [[ -n "$expected" ]] && ! grep -qF -- "$expected" "$log"; then
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
  local hook=$1 failures
  failures=$(grep -E '\.Failed$' "$log" || true)
  [[ "$(printf '%s\n' "$failures" | grep -c .)" -eq 1 ]] &&
    printf '%s\n' "$failures" | grep -q "^$hook"
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

# merge_fragment <stack>: merges the standards repo's hooks/<stack>.yaml into
# the current directory's .pre-commit-config.yaml the way a project does:
# fill in the source header's <sha>, then append the fragment unedited
# otherwise.
merge_fragment() {
  local fragment="$script_dir/../hooks/$1.yaml" sha
  sha=$(git -C "$script_dir" rev-parse HEAD)
  head -n 1 "$fragment" |
    grep -qxF "# from dominicfarr/dev-standards@<sha>" || {
    echo "$fragment lacks its source header placeholder"
    return 1
  }
  {
    printf '\n'
    sed "1s/<sha>/$sha/" "$fragment"
  } >>.pre-commit-config.yaml
}

# --- Python hook fragment ---------------------------------------------------

# python_scratch_uv: lays down a scratch uv project (tools pinned in the
# standards repo's scripts/fixtures/python) on source_repo's base gates, with
# the standards repo's hooks/python.yaml merged in.
python_scratch_uv() {
  merge_fragment python || return 1
  cp "$script_dir/fixtures/python/pyproject.toml" \
    "$script_dir/fixtures/python/uv.lock" .
  printf 'def add(a: int, b: int) -> int:\n    return a + b\n' >calc.py
  uv sync --locked --no-build
}

# python_scratch_project: the scratch uv project with a passing test.
python_scratch_project() {
  python_scratch_uv || return 1
  mkdir -p tests
  printf 'from calc import add\n\n\ndef test_add() -> None:\n    assert add(1, 2) == 3\n' \
    >tests/test_calc.py
}

case_python() {
  make_throwaway python python_scratch_project

  # A mutable default: ruff's fix for it is unsafe, so --fix leaves it.
  printf 'def collect(items: list[int] = []) -> list[int]:\n    return items\n' \
    >collect.py
  git add collect.py
  expect_rejected "Python lint error rejected by ruff check alone" \
    "feat: add a mutable default" "ruff check" "B006"

  printf 'from calc import add\n\ntotal: str = add(1, 2)\n' >typed.py
  git add typed.py
  expect_rejected "Python type error rejected by pyright alone" \
    "feat: add a mistyped total" pyright "reportAssignmentType"

  printf 'from calc import add\n\n\ndef test_add_wrong() -> None:\n    assert add(1, 2) == 4\n' \
    >tests/test_wrong.py
  git add tests/test_wrong.py
  expect_rejected "Python failing test rejected by pytest alone" \
    "test: add a wrong expectation" pytest "1 failed"

  printf 'from calc import add\n\n\ndef test_add_negative() -> None:\n    assert add(-1, -2) == -3\n' \
    >tests/test_negative.py
  git add tests/test_negative.py
  expect_accepted "good Python commit accepted" "test: cover negative numbers"

  cd "$workdir/base"
}

# A new project has no tests yet: pytest collects none (exit 5), and that
# must not stop the commit.
case_python_no_tests() {
  make_throwaway python-no-tests python_scratch_uv

  printf 'from calc import add\n\ntotal: int = add(1, 2)\n' >total.py
  git add total.py
  expect_accepted "Python commit with no tests yet accepted" \
    "feat: add a total"

  cd "$workdir/base"
}

# --- JS/TS hook fragment ----------------------------------------------------

# js_ts_scratch_project: lays down a scratch Svelte/TS project from the
# standards repo's scripts/fixtures/js-ts (with its npm lockfile) on
# source_repo's base gates, with the standards repo's hooks/js-ts.yaml merged
# in.
js_ts_scratch_project() {
  merge_fragment js-ts || return 1
  (cd "$script_dir/fixtures/js-ts" &&
    git ls-files -z -co --exclude-standard . | tar -cf - --null -T -) |
    tar -xf - -C .
  npm ci --ignore-scripts --no-audit --no-fund
}

case_js_ts() {
  make_throwaway js-ts js_ts_scratch_project

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

cases=(
  case_staged_secret
  case_non_conventional_message
  case_unknown_scope
  case_good_commit
  case_dependabot_commit
  case_js_ts
  case_python
  case_python_no_tests
)

printf 'Gate proof for %s\n' "$source_repo"
make_throwaway base
for case_fn in "${cases[@]}"; do
  "$case_fn"
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
