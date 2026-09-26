#!/usr/bin/env bash

function set_up() {
  set -euo pipefail
  TEST_TMP_DIR=$(mktemp -d)
  MOCK_BIN="${TEST_TMP_DIR}/bin"
  mkdir -p "${MOCK_BIN}"

  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/logger"
  chmod +x "${MOCK_BIN}/logger"

  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/docker"
  chmod +x "${MOCK_BIN}/docker"

  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/chown"
  chmod +x "${MOCK_BIN}/chown"

  printf '#!/usr/bin/env bash\n' >"${MOCK_BIN}/flock"
  chmod +x "${MOCK_BIN}/flock"

  export CF_FILE="${TEST_TMP_DIR}/cloudflare-ips.inc"
  local owner_user
  owner_user=$(id -un)
  local owner_group
  owner_group=$(id -gn)
  export OWNER="${owner_user}:${owner_group}"
  export CONTAINER_NAME="angie"
  export LOCK_FILE="${TEST_TMP_DIR}/update-cf-ips.lock"

  export PATH="${MOCK_BIN}:${PATH}"

  . "usr/local/bin/update-cf-ips.sh"
}

function tear_down() {
  rm -rf "${TEST_TMP_DIR}"
}

function test_usage_outputs_help_text() {
  local out
  out=$(usage)
  assert_contains "Usage:" "${out}"
  assert_contains "--help" "${out}"
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

function test_die_output_contains_iso_timestamp() {
  set +e
  local out
  out=$(die "timestamp check" 2>&1)
  set -e
  assert_matches '\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T' "${out}"
}

function test_log_outputs_message_to_stderr() {
  local out
  out=$(log "informational message" 2>&1)
  assert_contains "informational message" "${out}"
}

function test_log_output_contains_iso_timestamp() {
  local out
  out=$(log "timestamp check" 2>&1)
  assert_matches '\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T' "${out}"
}

function test_cleanup_removes_temp_file_when_tmp_file_is_set() {
  local test_file
  test_file=$(mktemp)
  TMP_FILE="${test_file}"
  export TMP_FILE

  assert_file_exists "${test_file}"
  cleanup
  assert_file_not_exists "${test_file}"
}

function test_cleanup_is_safe_when_tmp_file_is_empty() {
  TMP_FILE=""
  export TMP_FILE
  cleanup
  assert_successful_code
}

function test_cleanup_is_safe_when_tmp_file_points_to_nonexistent_file() {
  TMP_FILE="/nonexistent/path/file.tmp"
  export TMP_FILE
  cleanup
  assert_successful_code
}

function test_check_deps_fails_when_dependency_is_missing() {
  set +e
  local out
  out=$(PATH="/nonexistent_dir_for_test" check_deps 2>&1)
  local status=$?
  set -e

  assert_contains "missing dependencies" "${out}"
  assert_equals 1 "${status}"
}

create_curl_mock() {
  local ipv4_data=""
  local ipv6_data=""
  local i

  for i in $(seq 1 8); do
    ipv4_data="${ipv4_data}192.0.2.${i}/24
"
  done
  for i in $(seq 1 4); do
    ipv6_data="${ipv6_data}2001:db8:${i}::/48
"
  done

  cat >"${MOCK_BIN}/curl" <<MOCK_EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\${arg}" in
  *ips-v4)
    printf '%s' '${ipv4_data}'
    exit 0
    ;;
  *ips-v6)
    printf '%s' '${ipv6_data}'
    exit 0
    ;;
  *) ;;
  esac
done
exit 1
MOCK_EOF
  chmod +x "${MOCK_BIN}/curl"
}

function test_fetch_and_write_creates_valid_config_with_sufficient_lines() {
  create_curl_mock

  fetch_and_write

  assert_file_exists "${CF_FILE}"

  local raw_count
  raw_count=$(wc -l <"${CF_FILE}")
  local line_count
  line_count=$(printf "%s" "${raw_count}" | tr -d ' ')
  assert_greater_or_equal_than 10 "${line_count}"

  local first_line
  first_line=$(head -1 "${CF_FILE}")
  assert_contains "set_real_ip_from" "${first_line}"
}

function test_fetch_and_write_output_contains_set_real_ip_from_directives() {
  create_curl_mock

  fetch_and_write

  local raw_count
  raw_count=$(grep -c "set_real_ip_from" "${CF_FILE}")
  local directive_count
  directive_count=$(printf "%s" "${raw_count}" | tr -d ' ')
  assert_equals "12" "${directive_count}"
}

function test_fetch_and_write_rejects_data_with_too_few_lines() {
  cat >"${MOCK_BIN}/curl" <<'MOCK_EOF'
#!/usr/bin/env bash
printf "192.0.2.1/24\n"
MOCK_EOF
  chmod +x "${MOCK_BIN}/curl"

  set +e
  local out
  out=$(fetch_and_write 2>&1)
  local status=$?
  set -e

  assert_contains "invalid or incomplete" "${out}"
  assert_equals 1 "${status}"
}

function test_reload_container_skips_when_container_is_not_running() {
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
printf "false\n"
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  local out
  out=$(reload_container 2>&1)
  assert_contains "not running" "${out}"
}

function test_reload_container_succeeds_when_container_is_running() {
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
case "$*" in
*inspect*) printf "true\n" ;;
*angie\ -t*) exit 0 ;;
*angie\ -s\ reload*) exit 0 ;;
*) exit 0 ;;
esac
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  reload_container
  assert_successful_code
}

function test_reload_container_fails_on_syntax_check_error() {
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
case "$*" in
*inspect*) printf "true\n" ;;
*angie\ -t*) exit 1 ;;
*) exit 0 ;;
esac
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  set +e
  local out
  out=$(reload_container 2>&1)
  local status=$?
  set -e

  assert_contains "syntax check failed" "${out}"
  assert_equals 1 "${status}"
}

function test_reload_container_fails_on_reload_error() {
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
case "$*" in
*inspect*) printf "true\n" ;;
*angie\ -t*) exit 0 ;;
*angie\ -s\ reload*) exit 1 ;;
*) exit 0 ;;
esac
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  set +e
  local out
  out=$(reload_container 2>&1)
  local status=$?
  set -e

  assert_contains "failed to reload Angie" "${out}"
  assert_equals 1 "${status}"
}

function test_main_help_flag_exits_cleanly() {
  local out
  out=$(main --help)
  assert_contains "Usage:" "${out}"
  assert_successful_code
}

function test_main_runs_full_workflow() {
  create_curl_mock
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
printf "false\n"
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  (main) >/dev/null 2>&1
  assert_successful_code
  assert_file_exists "${CF_FILE}"
}

function test_fetch_and_write_fails_when_ipv4_fetch_fails() {
  cat >"${MOCK_BIN}/curl" <<'MOCK_EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case "${arg}" in
  *ips-v4*) exit 1 ;;
  *ips-v6*) printf "2001:db8::/32\n" ; exit 0 ;;
  *) ;;
  esac
done
exit 1
MOCK_EOF
  chmod +x "${MOCK_BIN}/curl"

  local out
  local status
  set +e
  out=$(
    set -o pipefail
    fetch_and_write 2>&1
  )
  status=$?
  set -e

  assert_contains "failed to fetch IPv4 lists" "${out}"
  assert_equals 1 "${status}"
}

function test_fetch_and_write_fails_when_ipv6_fetch_fails() {
  cat >"${MOCK_BIN}/curl" <<'MOCK_EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  case "${arg}" in
  *ips-v4*) printf "192.0.2.1/24\n" ; exit 0 ;;
  *ips-v6*) exit 1 ;;
  *) ;;
  esac
done
exit 1
MOCK_EOF
  chmod +x "${MOCK_BIN}/curl"

  local out
  local status
  set +e
  out=$(
    set -o pipefail
    fetch_and_write 2>&1
  )
  status=$?
  set -e

  assert_contains "failed to fetch IPv6 lists" "${out}"
  assert_equals 1 "${status}"
}

function test_main_handles_default_case_argument() {
  create_curl_mock
  cat >"${MOCK_BIN}/docker" <<'MOCK_EOF'
#!/usr/bin/env bash
printf "false\n"
MOCK_EOF
  chmod +x "${MOCK_BIN}/docker"

  (main --arbitrary-option) >/dev/null 2>&1
  assert_successful_code
}

function test_main_fails_when_lock_is_already_held() {
  cat >"${MOCK_BIN}/flock" <<'MOCK_EOF'
#!/usr/bin/env bash
exit 1
MOCK_EOF
  chmod +x "${MOCK_BIN}/flock"

  local out
  local status
  set +e
  out=$(
    set -e
    main 2>&1
  )
  status=$?
  set -e

  assert_contains "another instance is already running" "${out}"
  assert_equals 1 "${status}"
}

function test_script_direct_execution_with_help() {
  local out
  out=$(bash usr/local/bin/update-cf-ips.sh --help)
  assert_contains "Usage:" "${out}"
  assert_successful_code
}
