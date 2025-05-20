# Contributing to Open CDP Flutter SDK

Thank you for your interest in contributing to the Open CDP Flutter SDK! This document provides guidelines and instructions for contributing.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Testing](#testing)
- [Code Style](#code-style)
- [Documentation](#documentation)
- [License](#license)

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

## How to Contribute

### Reporting Bugs

- **Check Existing Issues**: Before reporting a bug, check the [issue tracker](https://github.com/code-matic/opencdp-flutter-sdk/issues) to see if it has already been reported.
- **Use the Bug Report Template**: When creating a new issue, use the bug report template and provide the following information:
  - **Description**: A clear and concise description of the bug.
  - **Steps to Reproduce**: Step-by-step instructions to reproduce the issue.
  - **Expected Behavior**: What you expected to happen.
  - **Actual Behavior**: What actually happened.
  - **Environment**: OS, Flutter version, SDK version, etc.
  - **Screenshots**: If applicable, add screenshots to help explain the issue.

### Suggesting Enhancements

- **Use the Feature Request Template**: When suggesting a new feature, use the feature request template and provide the following information:
  - **Description**: A clear and concise description of the feature.
  - **Use Case**: Explain why this feature would be useful.
  - **Proposed Solution**: If you have a solution in mind, describe it.

### Pull Requests

- **Fork the Repository**: Start by forking the repository.
- **Create a Branch**: Create a new branch for your feature or bug fix:
  ```bash
  git checkout -b feature/amazing-feature
  ```
- **Make Changes**: Make your changes and commit them with a clear message:
  ```bash
  git commit -m 'Add some amazing feature'
  ```
- **Push Changes**: Push your branch to your fork:
  ```bash
  git push origin feature/amazing-feature
  ```
- **Open a Pull Request**: Submit a pull request to the `main` branch of the original repository. Use the pull request template and provide a clear description of your changes.

---

## Development Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/code-matic/opencdp-flutter-sdk.git
   cd opencdp-flutter-sdk
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Tests**:
   ```bash
   flutter test
   ```

---

## Testing

- **Write Tests**: Ensure your code is covered by tests. Run the tests using:
  ```bash
  flutter test
  ```
- **Coverage**: Aim for high test coverage. You can generate a coverage report using:
  ```bash
  flutter test --coverage
  ```

---

## Code Style

- **Follow Dart Style Guide**: Adhere to the [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- **Format Code**: Use `dart format` to format your code:
  ```bash
  dart format .
  ```

---

## Documentation

- **Update README**: If your changes affect the README, update it accordingly.
- **Document Code**: Add comments to your code where necessary.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Thank you for contributing to the Open CDP Flutter SDK!
