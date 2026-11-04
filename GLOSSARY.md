# Dev Standards

The single source of Dom's development standards, which every new project copies from when it's created and when its stack is chosen.

## Language

**Standards repo**:
This repo: the one place the standard files and the development practices live.
_Avoid_: bootstrap, archetype, template repo

**Project**:
A repo that takes its files from the standards repo.
_Avoid_: target repo, app, consumer

**Standard**:
One fixed development choice that every project follows unless it records a reason not to (e.g. trunk-based development, uv for Python).
_Avoid_: convention, preference, practice

**Development practices**:
The document that sets out the standards for how a project is built, gated, delivered and analysed. Grilling reads it as settled scope.
_Avoid_: guidelines, playbook

**Base gates**:
The language-agnostic hooks and CI checks that a project has from its first commit, before any stack is chosen.
_Avoid_: archetype, skeleton

**Stack**:
A language toolchain a project is built with: JS/TS (Svelte) or Python. A project can have more than one.
_Avoid_: layer, language layer

**Hook fragment**:
A stack's set of pre-commit hooks, kept in the standards repo, that runs the stack's tools from the project's own lockfile, and is merged into a project's hooks once that stack is chosen.
_Avoid_: hook import, remote hook

**Source header**:
The first line of a copied file, naming the standards repo commit it came from, so drift from the current standard is visible.

**Extension point**:
A marked block in a copied file (the base CI, the Sonar templates) where a stack or a later ticket adds its own steps or values. Each is marked `EXTENSION POINT` in the file.
_Avoid_: extension slot, slot, hook point
