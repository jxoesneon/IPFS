# Contributing to dart_ipfs

Thank you for your interest in contributing to dart_ipfs! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

This project follows the Contributor Covenant Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- Dart SDK >=3.5.4 <4.0.0
- Git
- Basic understanding of IPFS concepts
- Familiarity with Dart/Flutter development

### Repository Structure

```
dart_ipfs/
├── lib/                    # Main library code
│   ├── dart_ipfs.dart     # Public API exports
│   └── src/               # Implementation
│       ├── core/          # Core IPFS functionality
│       ├── protocols/     # Protocol implementations
│       ├── services/      # HTTP Gateway, RPC
│       ├── transport/     # P2P networking
│       └── utils/         # Utilities
├── example/               # Example applications
├── test/                  # Test suite
├── README.md              # Main documentation
├── ROADMAP.md             # Future plans
└── CHANGELOG.md           # Version history
```

## Development Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/jxoesneon/IPFS.git
   cd IPFS
   ```

2. **Install dependencies**

   ```bash
   dart pub get
   ```

3. **Run static analysis**

   ```bash
   dart analyze
   ```

4. **Run tests**

   ```bash
   dart test
   ```

5. **Run examples**
   ```bash
   dart run example/blog_use_case.dart
   dart run example/online_test.dart
   ```

## How to Contribute

### Types of Contributions

We welcome:

- 🐛 **Bug fixes**
- ✨ **New features** (see ROADMAP.md for planned features)
- 📝 **Documentation improvements**
- ✅ **Test coverage improvements**
- 🎨 **Code quality improvements**
- 🌍 **Translation/i18n**
- 📦 **New examples**

### Good First Issues

Look for issues labeled `good-first-issue` on GitHub. These are suitable for newcomers.

### Feature Requests

Before implementing a new feature:

1. Check if it's in ROADMAP.md
2. Open a discussion on GitHub Discussions
3. Wait for maintainer feedback
4. Create an issue if approved

## Code Style

### Dart Style Guide

We follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style):

- Use `dart format` before committing
- Follow naming conventions:
  - Classes: `UpperCamelCase`
  - Variables/functions: `lowerCamelCase`
  - Constants: `lowerCamelCase`
  - Files: `snake_case.dart`

### Documentation

All public APIs must have:

````dart
/// Brief description.
///
/// Detailed explanation with examples.
///
/// **Example:**
/// ```dart
/// final node = await IPFSNode.create(config);
/// await node.start();
/// ```
///
/// Parameters:
/// - [config]: Configuration for the node
///
/// Returns: Initialized IPFS node
///
/// Throws: [Exception] if initialization fails
Future<IPFSNode> create(IPFSConfig config) async {
  // implementation
}
````

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding tests
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `chore`: Maintenance tasks

**Examples:**

```
feat(dht): add improved peer discovery
fix(gateway): resolve content-type detection bug
docs(readme): update installation instructions
test(bitswap): add message serialization tests
```

## Testing

### Running Tests

```bash
# All tests
dart test

# Specific test file
dart test test/protocol_test.dart

# Web Integration Tests (Chrome)
dart test -p chrome test/web/ipfs_web_node_test.dart

# With coverage
dart test --coverage=coverage
```

### Writing Tests

1. **Protocol Tests**: Ensure protocol compliance

   ```dart
   test('CID v1 encoding', () {
     final cid = CID.decode('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
     expect(cid.version, equals(1));
   });
   ```

2. **Integration Tests**: Test component interactions

   ```dart
   test('Add and retrieve content', () async {
     final node = await IPFSNode.create(config);
     final cid = await node.addFile(data);
     final retrieved = await node.get(cid);
     expect(retrieved, equals(data));
   });
   ```

3. **Unit Tests**: Test individual functions
   ```dart
   test('Base58 encoding', () {
     final encoded = Base58().encode([1, 2, 3]);
     expect(encoded, isNotEmpty);
   });
   ```

### Test Coverage

- Aim for >80% coverage for new code
- All public APIs must have tests
- Protocol implementations must have compliance tests

## Pull Request Process

### Before Submitting

1. ✅ Run `dart analyze` (0 errors, 0 warnings)
2. ✅ Run `dart test` (all tests pass)
3. ✅ Run `dart format .` (code formatted)
4. ✅ Update CHANGELOG.md if applicable
5. ✅ Add tests for new features
6. ✅ Update documentation

### PR Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

How has this been tested?

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests added/updated
- [ ] All tests pass
```

### Review Process

1. Automated checks must pass (CI/CD)
2. At least one maintainer review required
3. Address review feedback
4. Maintainer will merge when approved

## Reporting Bugs

### Before Reporting

1. Search existing issues
2. Try latest version
3. Verify it's reproducible

### Bug Report Template

```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:

1. Initialize node with...
2. Call method...
3. See error

**Expected behavior**
What should happen

**Actual behavior**
What actually happens

**Environment**

- dart_ipfs version: 1.0.0
- Dart SDK: 3.5.4
- OS: macOS 14.0
- Platform: Flutter/Web/CLI

**Additional context**
Logs, screenshots, etc.
```

## Suggesting Features

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
Description of the problem

**Describe the solution**
What you want to happen

**Describe alternatives**
Alternative solutions considered

**Additional context**
Use cases, examples, mockups
```

## Development Guidelines

### Architecture Principles

1. **Modularity**: Keep components loosely coupled
2. **Testability**: Write testable code
3. **Performance**: Consider efficiency
4. **Security**: Follow security best practices
5. **Documentation**: Document public APIs

### Protocol Implementation

When implementing IPFS protocols:

1. Follow official specifications
2. Add protocol compliance tests
3. Document deviations (if any)
4. Ensure interoperability with go-ipfs

### Error Handling

```dart
try {
  // operation
} catch (e, stackTrace) {
  _logger.error('Operation failed: $e');
  _logger.verbose('Stack trace: $stackTrace');
  throw IPFSException('User-friendly message', originalError: e);
}
```

### Logging

Use appropriate log levels:

```dart
_logger.error('Critical error');      // Errors
_logger.warning('Warning message');   // Warnings
_logger.info('Info message');         // Info
_logger.fine('Debug message');        // Debug
_logger.verbose('Trace message');     // Verbose
```

## Release Process

Maintainers only:

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Create git tag: `git tag v1.x.x`
4. Push tag: `git push origin v1.x.x`
5. Publish: `dart pub publish`
6. Create GitHub release

## Community

- **GitHub Discussions**: General questions, ideas
- **GitHub Issues**: Bug reports, feature requests
- **Pull Requests**: Code contributions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to:

- Open a discussion on GitHub
- Comment on relevant issues
- Tag maintainers in PRs

Thank you for contributing to dart_ipfs! 🚀
