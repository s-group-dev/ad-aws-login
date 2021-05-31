#!/usr/bin/env bash

set -euo pipefail

d="$(cd "$(dirname "${0}")" && pwd)"; cd "${d%/bin}"

# CONSTANTS
AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

# FUNCTIONS

# MAIN

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
EOF
    exit 128
}

function cleanup() {
    (
        rm -f "${TEMP_FILE}" || true
        kill "$(pgrep -lf \"${browser}.app\" | grep "${browser}.*--user-data-dir=${PWD}/user_data$" | awk '{ print $1; }')"
    ) &>/dev/null
}
trap cleanup EXIT

function argv() {
    arg="${1}"
    default="${2}"
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
    local config="${AWS_CONFIG_FILE}"
    local _AWS_PROFILE
    test ! -f "${config}" && echo "File ${config} does not exist" && return 1
    # If user has fzf installed
    if which fzf >/dev/null 2>&1; then
        _AWS_PROFILE=$(grep '\[profile' < "${config}" | sed 's/\[profile \(.*\)]/\1/' | fzf)
    else
        select _aws_profile in $(grep '\[profile' < "${config}" | sed 's/\[profile \(.*\)]/\1/'); do
            _AWS_PROFILE=$_aws_profile
            break
        done
    fi

    echo "${_AWS_PROFILE}"
}

readonly AWS_CONFIG=$AWS_CONFIG_FILE

PROFILE_NAME="$(argv profile "" "${@:-}")"
APP_NAME="$(argv app "" "${@:-}")"
DURATION_HOURS="$(argv duration 8 "${@:-}")"
ROLE_ARN="$(argv role-arn "" "${@:-}")"
AWS_CREDENTIALS=$AWS_SHARED_CREDENTIALS_FILE
TEMP_FILE="${HOME}/Downloads/temporary_aws_credentials$(date +"%Y-%m-%d_%H-%M-%S").txt"

[[ -z "${PROFILE_NAME}" ]] && PROFILE_NAME=$(_selaws)

PROFILE_CONFIG="$(sed -n "/${PROFILE_NAME}/,/^ *$/p" "${AWS_CONFIG}")"

if [[ -z $APP_NAME ]]; then
    APP_NAME=$(echo "${PROFILE_CONFIG}" | (grep 'app=.*' || true) | sed -E 's/^.*app *= *([^ ]*).*$/\1/')
fi

if [[ -z $ROLE_ARN ]]; then
    ROLE_ARN=$(echo "${PROFILE_CONFIG}" |  (grep 'role_arn=.*' || true) | sed -E 's/^.*role_arn *= *([^ ]*).*$/\1/')
fi

echo "const parameters = {
  durationHours: ${DURATION_HOURS},
  appName: \"${APP_NAME}\",
  filename: \"$(basename "${TEMP_FILE}")\",
  roleArn: \"${ROLE_ARN}\"
};" > "${PWD}/chrome_extension/parameters.js"

browser=
BROWSERS="Google Chrome
Microsoft Edge"

while read -r b; do
  if [[ -d "/Applications/${b}.app" ]]; then
    browser="${b}"
    break
  fi
done < <(echo "$BROWSERS")

if [[ -z "${browser}" ]]; then
  echo -e "Cannot find a browser from:\n${BROWSERS}." && exit 1
fi

args="--load-extension="${PWD}/chrome_extension" --disable-extensions-except="${PWD}/chrome_extension" --user-data-dir="${PWD}/user_data""
open -a "${browser}" -F -n "http://myapps.microsoft.com" --args $args

while true; do
    PID=$(ps aux | grep "${browser}.*--user-data-dir=${PWD}/user_data$" | grep -v grep | awk '{print $2;}' || true)
    if [[ ! -z "${PID}" ]]; then
        break
    fi
    sleep 1
done

until [ -f "${TEMP_FILE}" ]; do (sleep 1 && printf "."); done

# kill this browser
kill $PID

printf "\n"

if [[ ! -f $AWS_CREDENTIALS ]]; then
    touch $AWS_CREDENTIALS
fi

cp $AWS_CREDENTIALS $AWS_CREDENTIALS.bak
awk '/^\[/{keep=1} /^\['"${PROFILE_NAME}"'\]/{keep=0} {if (keep) {print $0}}' ${AWS_CREDENTIALS}.bak > ${AWS_CREDENTIALS}
printf "\n[%s]\n" "${PROFILE_NAME}" >> ${AWS_CREDENTIALS}
cat "${TEMP_FILE}" >> "${AWS_CREDENTIALS}"
echo "Updated profile ${PROFILE_NAME}."
tail -1 ${AWS_CREDENTIALS}