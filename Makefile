.PHONY: security-trivy \
       shell-lint shell-fmt shell-test shell-coverage shell-verify \
       go-fmt go-lint go-test go-coverage vulncheck go-verify \
       docker-lint secrets-scan verify clean

SHELL_SCRIPTS := $(shell find usr/local/bin -type f ! -name '.*')
TEST_SCRIPTS  := $(shell find tests -type f -name '*.sh')
ALL_SCRIPTS   := $(SHELL_SCRIPTS) $(TEST_SCRIPTS)
COVERAGE_DIR  := coverage

shell-lint:
	shellcheck --enable=all -x $(ALL_SCRIPTS)
	shfmt -d -s -i 2 $(ALL_SCRIPTS)
	checkbashisms -f $(ALL_SCRIPTS) || true

shell-fmt:
	shfmt -w -s -i 2 $(ALL_SCRIPTS)

shell-test:
	bashunit tests/

shell-coverage:
	rm -rf $(COVERAGE_DIR)
	bashunit tests/ --coverage --coverage-paths usr/local/bin

shell-verify: shell-lint shell-test

go-fmt:
	@test -z "$$(gofmt -s -l .)" || (echo "Unformatted files found. Run 'gofmt -s -w .' to fix them." && false)

go-lint:
	golangci-lint run ./...
	go build -o /dev/null ./probe

go-test:
	go test -v -race ./...

go-coverage:
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -func=coverage.out

vulncheck:
	govulncheck ./...

go-verify: go-fmt go-lint go-test vulncheck

docker-lint:
	hadolint Dockerfile

secrets-scan:
	gitleaks detect --source . --no-git --no-color

security-trivy:
	trivy fs --severity CRITICAL,HIGH .

verify: shell-verify go-verify docker-lint secrets-scan security-trivy

clean:
	rm -rf $(COVERAGE_DIR) .bashunit coverage.out
