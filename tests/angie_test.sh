#!/usr/bin/env bash

function set_up() {
  set -euo pipefail
  TEST_TMP_DIR=$(mktemp -d)
  MOCK_BIN="${TEST_TMP_DIR}/bin"
  mkdir -p "${MOCK_BIN}"

  printf '#!/usr/bin/env bash\nexit 0\n' >"${MOCK_BIN}/docker"
  chmod +x "${MOCK_BIN}/docker"

  export CONTAINER_NAME="test_angie"
  export PATH="${MOCK_BIN}:${PATH}"

  . "usr/local/bin/angie"
}

function tear_down() {
  rm -rf "${TEST_TMP_DIR}"
}

function test_usage_outputs_help_text() {
  local out
  out=$(usage)
  assert_contains "Usage:" "${out}"
  assert_contains "--help" "${out}"
  assert_contains "CONTAINER_NAME" "${out}"
  assert_contains "TRACE=1" "${out}"
}

function test_die_exits_with_code_1() {
  set +e
  (die "test error message" 2>/dev/null)
  local status=$?
  set -e
  assert_equals 1 "${status}"
}

function test_die_outputs_error_to_stderr() {
  set +e
  local out
  out=$(die "test error message" 2>&1)
  set -e
  assert_contains "ERROR: test error message" "${out}"
}

function test_check_deps_succeeds_when_docker_present() {
  assert_successful_code check_deps
}

function test_check_deps_fails_when_docker_missing() {
  local empty_bin="${TEST_TMP_DIR}/empty_bin"
  mkdir -p "${empty_bin}"

  set +e
  local out
  out=$(PATH="${empty_bin}" check_deps 2>&1)
  local status=$?
  set -e

  assert_equals 1 "${status}"
  assert_contains "missing required dependency: docker" "${out}"
}

function test_main_help_flag_displays_usage_and_exits_0() {
  local out
  out=$(main --help)
  assert_contains "Usage:" "${out}"
  assert_contains "Execute Angie commands" "${out}"
}

function test_main_fails_when_container_not_running() {
  cat <<'EOF' >"${MOCK_BIN}/docker"
#!/usr/bin/env bash
if [[ "$1" == "inspect" ]]; then
  echo "false"
  exit 0
fi
exit 0
EOF
  chmod +x "${MOCK_BIN}/docker"

  set +e
  local out
  out=$(main -t 2>&1)
  local status=$?
  set -e

  assert_equals 1 "${status}"
  assert_contains "container 'test_angie' is not running" "${out}"
}

function test_main_executes_docker_exec_when_running() {
  cat <<'EOF' >"${MOCK_BIN}/docker"
#!/usr/bin/env bash
if [[ "$1" == "inspect" ]]; then
  echo "true"
  exit 0
fi
if [[ "$1" == "exec" ]]; then
  echo "executed: $*"
  exit 0
fi
exit 0
EOF
  chmod +x "${MOCK_BIN}/docker"

  local out
  out=$(main -t)
  assert_contains "executed: exec -i test_angie angie -t" "${out}"
}
