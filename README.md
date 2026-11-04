# dev-standards

[![CI](https://github.com/dominicfarr/dev-standards/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dominicfarr/dev-standards/actions/workflows/ci.yml)

The standards repo: the one place Dom's standard files and development practices live. Every new project copies its files from here when it's created and when its stack is chosen. See [PLAN.md](PLAN.md) for what's here and what's coming, and [GLOSSARY.md](GLOSSARY.md) for the terms.

This repo follows its own standards: its commits go through the base gates, and [CONTRIBUTING.md](CONTRIBUTING.md) is the standard one.

## Development setup

You need:

- [uv](https://docs.astral.sh/uv/)
- pre-commit: `uv tool install pre-commit==4.7.0` (the version CI uses; bump both together)
- shellcheck: `brew install shellcheck`, or `uv tool install shellcheck-py`

Then install the hooks for both the `pre-commit` and `commit-msg` stages:

```sh
pre-commit install --install-hooks
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and the commit message format.

## Gate proof

`scripts/gate-proof.sh` re-proves the base gates after any change to them. It copies the repo into a throwaway git repo, installs the hooks there, and shows that commits are rejected for a staged fake secret (by gitleaks alone), a non-conventional message and an unknown scope, that a good commit passes, and that Dependabot's commits are not linted. It changes nothing in your checkout.

It also proves the JS/TS hook fragment (`hooks/js-ts.yaml`): it builds a scratch Svelte/TS project from `scripts/fixtures/js-ts`, which has its own npm lockfile, and merges the fragment into the base config the way a project does: its source header filled in with the commit, the rest appended unedited. It then shows that a lint error, a type error and a failing related test are each rejected by their own hook, and that a good commit passes. This case needs npm and network access for `npm ci`.

It proves the Python hook fragment (`hooks/python.yaml`) the same way: a scratch uv project whose `pyproject.toml` and `uv.lock` in `scripts/fixtures/python` pin ruff, pyright and pytest, with the fragment appended to the base config. A lint error, a type error and a failing test are each rejected by their own hook, a good commit passes, and a project with no tests yet can still commit. This case needs uv and network access for `uv sync`.

```sh
scripts/gate-proof.sh            # this repo
scripts/gate-proof.sh ../project # any repo with the base gates
```
