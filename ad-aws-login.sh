#!/usr/bin/env bash

set -euo pipefail

d="$(cd "$(dirname "${0}")" && pwd)"; cd "${d%/bin}"

# Helper functions

function argv() {
  local arg="${1}"
  local default="${2}"
  shift; shift

  while (( "$#" )); do
    if [[ "$1" == "--${arg}" ]]; then
      echo "$2"
      return
    fi
    shift; shift
  done

  echo "${default}"
}

function _selaws() {
  local _AWS_PROFILE
  test ! -f "${AWS_CONFIG_FILE}" && echo "File ${AWS_CONFIG_FILE} does not exist" && return 1
  # If user has fzf installed
  if hash fzf &>/dev/null; then
    _AWS_PROFILE=$(grep '\[profile' < "${AWS_CONFIG_FILE}" | sed 's/\[profile \(.*\)]/\1/' | fzf)
  else
    select _aws_profile in $(grep '\[profile' < "${AWS_CONFIG_FILE}" | sed 's/\[profile \(.*\)]/\1/'); do
      _AWS_PROFILE=$_aws_profile
      break
    done
  fi

  echo "${_AWS_PROFILE}"
}

# CONSTANTS

readonly AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
readonly AWS_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
readonly TEMP_FILE="${HOME}/Downloads/temporary_aws_credentials$(date +"%Y-%m-%d_%H-%M-%S").txt"
readonly DURATION_HOURS="$(argv duration 8 "${@:-}")"
readonly BROWSERS="Google Chrome
Microsoft Edge"

# VARIABLES

USER_BROWSER=

# FUNCTIONS

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]
  Simple script that fetches temporary AWS credentials with Azude AD login
  (https://myapps.microsoft.com).
Options:
  --profile  TEXT    The name of the profile in ~/.aws/credentials to update.
  --app      TEXT    A substring of the app name shown in myapps.microsoft.com
                     to launch. Case-insensitive. Must be url encoded.
  --duration INTEGER How many hours the temporary credentials are valid.
  --role-arn TEXT    AWS IAM Role to assume with AD credentials.
  -h, --help         Show this help message and exit.
EOF
  exit 0
}

function exit_error() {
  local error_code="$1"
  shift
  1>&2 echo -e "$@"
  exit ${error_code}
}

function cleanup() {
  (
    rm -f "${TEMP_FILE}" || true
    kill "$(pgrep -lf "${USER_BROWSER}.app" | grep "${USER_BROWSER}.*--user-data-dir=${PWD}/user_data$" | awk '{print $1;}')"
  ) &>/dev/null
}

function handle_browser() {
  local browser
  while read -r browser; do
    if [[ -d "/Applications/${browser}.app" ]]; then
      readonly USER_BROWSER="${browser}"
      break
    fi
  done < <(echo "$BROWSERS")
  trap cleanup EXIT
  
  if [[ -z "${USER_BROWSER}" ]]; then
    exit_error 1 "Cannot find a browser from:\n${BROWSERS}."
  fi
  
  args="--load-extension="${PWD}/chrome_extension" --disable-extensions-except="${PWD}/chrome_extension" --user-data-dir="${PWD}/user_data""
  # shellcheck disable=SC2086
  open -a "${USER_BROWSER}" -F -n "http://myapps.microsoft.com" --args ${args}
  
  while true; do
    PID=$(pgrep -lf "${USER_BROWSER}\.app.*--user-data-dir=${PWD}/user_data$" | grep -v grep | awk '{print $1;}' || true)
    if [[ -n "${PID}" ]]; then
      break
    fi
    sleep 1
  done

  until [ -f "${TEMP_FILE}" ]; do (sleep 1 && printf "."); done

  # kill this browser
  kill "${PID}"
}

function create_params() {
  local app="$1"
  local role="$2"
  echo "const parameters = {
  durationHours: ${DURATION_HOURS},
  appName: \"${app}\",
  filename: \"$(basename "${TEMP_FILE}")\",
  roleArn: \"${role}\"
  };" > "${PWD}/chrome_extension/parameters.js"
}

function persist_credentials() {
  local profile_name="$1"
  if [[ ! -f "${AWS_CREDENTIALS_FILE}" ]]; then
    touch "${AWS_CREDENTIALS_FILE}"
  fi

  cp "${AWS_CREDENTIALS_FILE}" "${AWS_CREDENTIALS_FILE}.bak"
  awk '/^\[/{keep=1} /^\['"${profile_name}"'\]/{keep=0} {if (keep) {print $0}}' "${AWS_CREDENTIALS_FILE}.bak" > "${AWS_CREDENTIALS_FILE}"
  printf "\n[%s]\n" "${profile_name}" >> "${AWS_CREDENTIALS_FILE}"
  cat "${TEMP_FILE}" >> "${AWS_CREDENTIALS_FILE}"
  echo "Updated profile ${profile_name}."
  tail -1 "${AWS_CREDENTIALS_FILE}"
}

function read_config() {
  local profile_name="$(argv profile "" "${@:-}")"
  [[ -z "${profile_name}" ]] && profile_name=$(_selaws)
  if [[ -z "${profile_name}" ]]; then
    exit_error 1 "Profile name cannot be empty."
  fi

  readonly PROFILE_CONFIG="$(sed -n "/${profile_name}/,/^ *$/p" "${AWS_CONFIG_FILE}")"

  app_name="$(argv app "" "${@:-}")"
  [[ -z "${app_name}" ]] && app_name=$(echo "${PROFILE_CONFIG}" | (grep 'app=.*' || true) | sed -E 's/^.*app *= *([^ ]*).*$/\1/')
  
  role_arn="$(argv role-arn "" "${@:-}")"
  [[ -z "${role_arn}" ]] && role_arn=$(echo "${PROFILE_CONFIG}" |  (grep 'role_arn=.*' || true) | sed -E 's/^.*role_arn *= *([^ ]*).*$/\1/')

  echo "${app_name} ${role_arn} ${profile_name}"
}

function main() {
  read app_name role_arn profile_name < <(read_config "$@")
  create_params "${app_name}" "${role_arn}"
  handle_browser
  until [ -f "${TEMP_FILE}" ]; do (sleep 1 && printf "."); done
  
  printf "\n"
  persist_credentials "${profile_name}"
}

# MAIN

if echo "$@" | grep -q -- '\(^\| \)--h\(elp\)\?\b'; then
  usage
fi

main "$@"