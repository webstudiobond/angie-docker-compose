#!/usr/bin/env bash

set -euo pipefail
[[ ${TRACE:-0} == "1" ]] && set -x

PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

: "${CF_FILE:=/home/angie/data/conf.d/cloudflare-ips.inc}"
: "${OWNER:=angie:angie}"
: "${CONTAINER_NAME:=angie}"
: "${LOCK_FILE:=/var/lock/update-cf-ips.lock}"
: "${CF_IPV4_URL:=https://www.cloudflare.com/ips-v4}"
: "${CF_IPV6_URL:=https://www.cloudflare.com/ips-v6}"
: "${MIN_EXPECTED_LINES:=10}"

TMP_FILE=""

usage() {
  printf "Usage: %s [options]\n\n" "$(basename "$0")"
  printf "Fetch current Cloudflare IP ranges and write an Angie/nginx\n"
  printf "set_real_ip_from include file, then reload the running container.\n\n"
  printf "Options:\n"
  printf "  -h, --help    Show this help message and exit\n\n"
  printf "Environment:\n"
  printf "  TRACE=1       Enable bash execution tracing (set -x)\n"
}

readonly LOGGER_TAG="update-cf-ips"

die() {
  local timestamp
  timestamp=$(date -Iseconds)
  printf "[%s] ERROR: %s\n" "${timestamp}" "$*" >&2
  logger -t "${LOGGER_TAG}" -p user.err "$*"
  exit 1
}

log() {
  local timestamp
  timestamp=$(date -Iseconds)
  printf "[%s] %s\n" "${timestamp}" "$*" >&2
  logger -t "${LOGGER_TAG}" -p user.info "$*"
}

cleanup() {
  if [[ -n ${TMP_FILE} && -f ${TMP_FILE} ]]; then
    rm -f "${TMP_FILE}"
  fi
}

check_deps() {
  local missing=()
  local cmd
  for cmd in curl awk docker chown chmod mv wc grep flock logger; do
    command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "missing dependencies: ${missing[*]}"
  fi
}

fetch_and_write() {
  TMP_FILE=$(mktemp) || die "failed to create temp file"

  if ! curl -fSs "${CF_IPV4_URL}" | awk '{print "set_real_ip_from " $1 ";"}' >>"${TMP_FILE}"; then
    die "failed to fetch IPv4 lists"
  fi

  if ! curl -fSs "${CF_IPV6_URL}" | awk '{print "set_real_ip_from " $1 ";"}' >>"${TMP_FILE}"; then
    die "failed to fetch IPv6 lists"
  fi

  local line_count
  line_count=$(wc -l <"${TMP_FILE}")
  if [[ ${line_count} -lt ${MIN_EXPECTED_LINES} ]]; then
    die "downloaded data seems invalid or incomplete (lines: ${line_count})"
  fi

  chmod 600 "${TMP_FILE}" || die "failed to set permissions"
  chown "${OWNER}" "${TMP_FILE}" || die "failed to set ownership"
  mv "${TMP_FILE}" "${CF_FILE}" || die "failed to move config file to destination"
  TMP_FILE=""
}

reload_container() {
  if ! docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null | grep -q "true"; then
    log "Container ${CONTAINER_NAME} is not running. Configuration saved, reload skipped."
    return
  fi

  if ! docker exec "${CONTAINER_NAME}" angie -t >/dev/null 2>&1; then
    die "Angie syntax check failed. Config not reloaded."
  fi

  docker exec "${CONTAINER_NAME}" angie -s reload >/dev/null || die "failed to reload Angie"
}

main() {
  case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  *) : ;;
  esac

  check_deps
  trap cleanup EXIT INT TERM ERR

  (
    flock -n 9 || die "another instance is already running"
    fetch_and_write
    reload_container
  ) 9>"${LOCK_FILE}"

  log "Cloudflare IPs updated successfully."
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
