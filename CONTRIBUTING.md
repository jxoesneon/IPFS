# Contributing to dart_ipfs

Thank you for contributing to dart_ipfs. This document describes the guidelines for submitting bug reports, proposing changes, and maintaining code quality.

## Reporting Bugs

When submitting a bug report, include the following information:

- A clear, descriptive title that identifies the problem.
- Exact steps to reproduce the issue, with as much detail as possible.
- Specific examples or code snippets that demonstrate the behavior.
- The expected behavior and the actual behavior.
- The Dart/Flutter version and platform where the issue occurs.

## Proposing Changes

1. Fork the repository and create a branch from `master`.
2. Add or update tests for any code changes.
3. Ensure the test suite passes locally (`dart test`).
4. Ensure static analysis reports no issues (`dart analyze`).
5. Format the code with `dart format .` before committing.
6. Open a pull request with a clear description of the change and the problem it solves.

## Styleguides

### Dart Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
- Run `dart format .` before committing.
- Maintain or improve test coverage for new and modified code.

### Commit Messages

- Use the present tense ("Add feature" rather than "Added feature").
- Use the imperative mood ("Move cursor to..." rather than "Moves cursor to...").
- Keep the first line concise and summarize the change.

## Questions and Discussions

For general questions, design discussions, or feature proposals, use [GitHub Discussions](https://github.com/jxoesneon/IPFS/discussions).
