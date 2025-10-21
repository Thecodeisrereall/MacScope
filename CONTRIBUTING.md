# Contributing to MacScope Install

Thank you for considering contributing to MacScope Install! This document provides guidelines for contributions.

## 🌟 How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/macscope-install/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and system info
   - Relevant log excerpts

### Suggesting Enhancements

1. Check existing issues for similar suggestions
2. Create a new issue with:
   - Clear use case
   - Proposed solution
   - Why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes following our coding standards
4. Test thoroughly on macOS 13.0+
5. Commit with clear messages: `git commit -m "Add feature: description"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request with:
   - Description of changes
   - Related issue number (if applicable)
   - Testing performed

## 📝 Coding Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote all variables: `"$VAR"`
- Use meaningful function names
- Add comments for complex logic
- Follow Google Shell Style Guide

### Commit Messages

Format: `<type>: <subject>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Build process or auxiliary tool changes

Example: `feat: add automatic driver version detection`

## 🧪 Testing

Before submitting PR:

1. Test on clean macOS installation
2. Test with existing installations
3. Test uninstall procedure
4. Verify logs are generated correctly
5. Check for shell script errors: `shellcheck scripts/*.sh`

## 📋 Pull Request Checklist

- [ ] Code follows style guidelines
- [ ] Self-review of code completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated as needed
- [ ] All tests pass
- [ ] Changes work on macOS 13.0+

## 🔒 Security

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email security concerns to: security@macscope.example.com
3. Include details of the vulnerability
4. Allow time for fix before public disclosure

## 💬 Questions?

Feel free to open a discussion or reach out via:
- GitHub Discussions
- Project Issues
- Email: support@macscope.example.com

## 📜 Code of Conduct

This project follows a Code of Conduct. By participating, you agree to:
- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other contributors

Thank you for making MacScope Install better! 🎉
