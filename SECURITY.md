# Security Policy

Thank you for helping keep SwiftState safe for the Swift and SwiftUI community.

## Supported Versions

SwiftState is currently maintained from the `main` branch while the package is being actively developed.

| Version | Supported |
| --- | --- |
| `main` | Yes |
| older release tags | Best effort |

## Reporting A Vulnerability

Please do not open a public GitHub issue for security vulnerabilities.

If you believe you have found a security issue, report it privately through GitHub Security Advisories when available, or contact the repository maintainer privately through GitHub.

When reporting, please include:

- A clear description of the issue
- Steps to reproduce
- Affected SwiftState version, branch, or commit
- Example code or proof of concept, if possible
- Any known impact or workaround

## Response Expectations

Maintainers will make a best-effort attempt to acknowledge valid reports within 72 hours.

If the report is confirmed, the fix will be prepared privately when appropriate and published with a short security note.

## Scope

Security reports may include:

- Unsafe state handling that could expose sensitive data
- Incorrect debug tooling behavior that could leak application state
- Supply-chain, package, or repository configuration issues
- Vulnerabilities in example code that users may copy into apps

Out-of-scope reports include:

- General feature requests
- Issues requiring a compromised developer machine
- Vulnerabilities in dependencies or host applications outside SwiftState
- Publicly disclosed issues without a private report first

## Bounty Program

SwiftState does not currently offer a paid bug bounty program.
