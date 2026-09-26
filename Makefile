.PHONY: compose-validate security-trivy \
       shell-lint shell-fmt shell-test shell-coverage shell-verify secrets-scan \
       verify clean

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

secrets-scan:
	gitleaks detect --source . --no-git --no-color

compose-validate:
	docker compose -f docker-compose.yaml config --quiet

security-trivy:
	trivy fs --severity CRITICAL,HIGH .

verify: compose-validate shell-verify secrets-scan security-trivy

clean:
	rm -rf $(COVERAGE_DIR) .bashunit

