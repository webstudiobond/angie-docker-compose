# Hardened Angie Edge Development Guide

## Prerequisites

Ensure the following dependencies are installed prior to local development:
- Git
- GNU Make
- Docker & Docker Compose (required for static compose manifest validation)
- bashunit (required for unit test execution)
- shellcheck (required for shell script static analysis)
- shfmt (required for shell code formatting)
- checkbashisms (required for script portability checking)
- gitleaks (required for secret and credential detection)
- trivy (required for filesystem and vulnerability scanning)

## Repository Initialization

Clone the repository and navigate into the project root:

```sh
git clone https://github.com/webstudiobond/angie-docker-compose
cd angie-docker-compose
```

## Code Validation & Testing

The project enforces strict code quality and security standards across all shell scripts, configuration snippets, and manifests. All validation workflows are centralized in the `Makefile`.

1. **Shell Script Linting & Static Analysis:**
   To execute static analysis with `shellcheck`, verify formatting diffs with `shfmt`, and verify portability with `checkbashisms`:
   ```sh
   make shell-lint
   ```

2. **Unit Testing & Coverage:**
   To execute the unit test suites:
   ```sh
   make shell-test
   ```
   To execute tests and generate line coverage reports in `coverage/`:
   ```sh
   make shell-coverage
   ```

3. **Secret Scanning:**
   To scan the repository for committed credentials, API tokens, or secrets:
   ```sh
   make secrets-scan
   ```

4. **Docker Compose Manifest Validation:**
   If Docker Compose is available locally, validate the syntax and schema of `docker-compose.yaml`:
   ```sh
   make compose-validate
   ```
   Alternatively, run directly:
   ```sh
   docker compose -f docker-compose.yaml config -q
   ```

5. **Filesystem Security Scanning:**
   To audit the repository filesystem for vulnerabilities using `trivy`:
   ```sh
   make security-trivy
   ```

6. **Project Verification:**
   Prior to submitting any pull request, you must execute the primary validation and test suite:
   ```sh
   make verify
   ```

## Testing Architecture & Standards

All unit tests reside in the `tests/` directory, named `<script_name>_test.sh`, and are executed with `bashunit`.

1. **Isolation & Sandboxing:** Each test runs inside an isolated temporary directory created via `mktemp -d`. All temporary state, mocks, and FIFOs are cleaned up in `tear_down()`.
2. **Zero External Calls:** Tests must never make real network requests or connect to running Docker daemons. External HTTP endpoints and system binaries (such as `docker`, `curl`, `chown`, `flock`) are intercepted using local test doubles, function mocks, and `PATH` stubs.
3. **Deterministic Fixtures:** Test inputs utilize synthetic data and reserved example domains (`example.com`, `example.net`). Real-world domains, production IP ranges, or live credentials are strictly forbidden.
4. **Failure Injection:** Error handling is covered by mocking command failures (e.g. simulating network timeouts, invalid HTTP payload responses, syntax check failures, container reload errors, and lock contention).

## Makefile Targets Reference

| Target | Description |
| --- | --- |
| `make shell-lint` | Analyzes all scripts and test files with `shellcheck`, verifies formatting diffs with `shfmt -d`, and checks portability with `checkbashisms`. |
| `make shell-fmt` | Automatically formats all shell scripts and test files in-place using `shfmt -w -s -i 2`. |
| `make shell-test` | Executes the complete test suite using `bashunit tests/`. |
| `make shell-coverage` | Runs unit tests and generates line coverage reports in `coverage/lcov.info`. |
| `make shell-verify` | Sequentially executes `shell-lint` and `shell-test`. |
| `make secrets-scan` | Scans the repository for committed secrets, tokens, and credentials using `gitleaks`. |
| `make compose-validate` | Validates `docker-compose.yaml` syntax locally via Docker Compose. |
| `make security-trivy` | Scans the repository filesystem for `CRITICAL` and `HIGH` severity vulnerabilities using `trivy`. |
| `make verify` | Full quality gate executing `compose-validate`, `shell-verify`, `secrets-scan`, and `security-trivy`. **Must be executed prior to submitting a pull request.** |
| `make clean` | Removes test coverage reports (`coverage/`) and test runner cache (`.bashunit/`). |
