# Contributing to OCPP Rails

Thank you for your interest in contributing to OCPP Rails! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites
- Ruby 3.0+
- Rails 7.0+ (optimized for Rails 8)
- SQLite3
- Git

### Development Setup

1. Fork the repository on GitHub

2. Clone your fork:
```bash
git clone https://github.com/YOUR_USERNAME/ocpp-rails.git
cd ocpp-rails
```

3. Install dependencies:
```bash
bundle install
```

4. Set up the test database:
```bash
cd test/dummy
rails db:migrate RAILS_ENV=test
cd ../..
```

5. Run the test suite to verify setup:
```bash
rails test
```

## Making Changes

### Workflow

1. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes with clear, focused commits

3. Write tests for new functionality

4. Ensure all tests pass:
```bash
rails test
```

5. Push to your fork and create a Pull Request

### Commit Messages

Write clear, descriptive commit messages:
- Use present tense ("Add feature" not "Added feature")
- Keep first line under 72 characters
- Reference issue numbers when applicable

Example:
```
Add StatusNotification error handling

- Handle connector status transitions
- Add validation for invalid status values
- Fixes #123
```

## Code Guidelines

### Style
- Follow Ruby community style guidelines
- Use 2 spaces for indentation
- Keep lines under 120 characters when possible
- Write descriptive variable and method names

### Testing
- All new features must include tests
- Maintain or improve test coverage
- Tests should be clear and focused
- Use factories/fixtures for test data

### Documentation
- Update README.md for user-facing changes
- Add inline documentation for complex logic
- Update relevant guides in docs/ directory
- Include code examples where helpful

## Reporting Issues

### Bug Reports

Include:
- OCPP Rails version
- Rails version
- Ruby version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or error messages

### Feature Requests

Include:
- Clear use case description
- Why this feature is valuable
- Proposed implementation approach (optional)
- How it fits with OCPP specification

## Code Review Process

1. Maintainers will review PRs as time permits
2. Address review feedback with new commits
3. Once approved, maintainers will merge
4. PRs may be closed if inactive for 30+ days

## OCPP Compliance

When implementing OCPP features:
- Follow OCPP 1.6 Edition 2 specification
- Include message examples in documentation
- Add integration tests covering full message flow
- Handle all required and optional fields per spec

## Questions?

- Check [documentation](docs/)
- Search [existing issues](https://github.com/trahfo/ocpp-rails/issues)
- Open a [discussion](https://github.com/trahfo/ocpp-rails/discussions)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
