// Conventional Commits, restricted to the types and scopes in CONTRIBUTING.md.
// Change this file and CONTRIBUTING.md together.
export default {
  extends: ['@commitlint/config-conventional'],
  // Dependabot writes its own headers, e.g. `ci(deps): bump actions/checkout
  // from 4 to 5`, but its bodies carry release notes with long lines, so its
  // signed-off commits are not linted.
  ignores: [(message) => message.includes('Signed-off-by: dependabot[bot]')],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'refactor',
        'perf',
        'test',
        'docs',
        'build',
        'ci',
        'chore',
        'revert',
      ],
    ],
    // Base scopes. A project adds its glossary terms here and in
    // CONTRIBUTING.md.
    'scope-enum': [2, 'always', ['deps', 'adr']],
    'header-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 72],
  },
};
