#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
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
trap cleanup EXIT
function cleanup() {
    (
        rm -f "${TEMP_FILE}" || true
        kill "$(pgrep -lf 'Chrome.app' | grep 'temporary_aws_credentials' | awk '{ print $1; }')"
    ) &>/dev/null
}
argv() {
    arg="${1}"
    default="${2}"
    shift; shift
    echo "${*}" | grep "\-\-${arg}" &>/dev/null \
        && echo "${*}" | sed -E "s/.*--${arg} ([^ ]*)(.*)?/\1/" \
        || echo "${default}"
}
[[ $# -eq 0 ]] && ( usage && exit 0 )
PROFILE_NAME="$(argv profile "" "${*:-}")"
APP_NAME="$(argv app "" "${*:-}")"
DURATION_HOURS="$(argv duration 4 "${*:-}")"
ROLE_ARN="$(argv role-arn "" "${*:-}")"
AWS_CREDENTIALS=~/.aws/credentials
TEMP_FILE="${HOME}/Downloads/temporary_aws_credentials$(date +"%Y-%m-%d_%H-%M-%S").txt"
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --load-extension="${PWD}/chrome_extension" --disable-extensions-except="${PWD}/chrome_extension" \
    --user-data-dir="${PWD}/user_data" \
    "http://localhost/?durationHours=${DURATION_HOURS}&app=${APP_NAME}&filename=$(basename "${TEMP_FILE}")&roleArn=${ROLE_ARN}" 2>/dev/null &
until [ -f "${TEMP_FILE}" ]; do (sleep 1 && echo -n .); done
echo
[[ -z "${PROFILE_NAME}" ]] && select _profile in $(sed '/\[profile/!d; s/^\[profile \([^]]*\)\]/\1/' "${HOME}/.aws/config")
do
    PROFILE_NAME="${_profile}"
    break
done
awk '/^\[/{keep=1} /^\['"${PROFILE_NAME}"'\]/{keep=0} {if (keep) {print $0}}' ${AWS_CREDENTIALS}.bak > ${AWS_CREDENTIALS}
echo -e "\n[${PROFILE_NAME}]" >> ${AWS_CREDENTIALS}
cat "${TEMP_FILE}" >> "${AWS_CREDENTIALS}"
echo "Updated profile ${PROFILE_NAME}."