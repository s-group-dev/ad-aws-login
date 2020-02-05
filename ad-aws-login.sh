#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME=
APP_NAME=
DURATION_HOURS=4
ROLE_ARN=

readonly AWS_CONFIG="${HOME}/.aws/config"
readonly AWS_CREDENTIALS=~/.aws/credentials
readonly THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
readonly EXTENSION="$THIS_DIR/chrome_extension"
readonly USER_DATA_DIR="$THIS_DIR/user_data"
readonly TEMP_FILE="${HOME}/Downloads/temporary_aws_credentials$(date +"%Y-%m-%d_%H-%M-%S").txt"

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

function err() {
    echo "$@" >&2
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            PROFILE_NAME=$2
            shift
            shift
            ;;
        -a|--app)
            APP_NAME=$2
            shift
            shift
            ;;
        -d|--duration)
            DURATION_HOURS=$2
            shift
            shift
            ;;
        -r|--role-arn)
            ROLE_ARN=$2
            shift
            shift
            ;;
        *)
            usage
            ;;
    esac
done

function selaws() {
    select _profile in $(cat "${AWS_CONFIG}" | grep '\[profile' | sed 's/\[profile \(.*\)]/\1/'); do
        echo $_profile
        break
    done
}

# Check that AWS config and selected profile exists.
if [ ! -f "${AWS_CONFIG}" ]; then
    err "AWS config file (${AWS_CONFIG}) does not exist. Cannot continue."
    exit 1
fi

if [[ -z $PROFILE_NAME ]]; then
    echo "No AWS profile given, select manually:"
    PROFILE_NAME=$(selaws)
fi

if ! cat "${AWS_CONFIG}" | grep -q "^\[profile ${PROFILE_NAME}\]$"; then
    err "Profile ${PROFILE_NAME} not found in ${AWS_CONFIG}."
    exit 2
fi

PROFILE_CONFIG="$(sed -n "/${PROFILE_NAME}/,/^ *$/p" ${AWS_CONFIG})"

if [[ -z $APP_NAME ]]; then
    APP_NAME=$(echo ${PROFILE_CONFIG} | (grep 'app*' || true) | sed -E 's/^.*app *= *([^ ]*).*$/\1/')
fi

if [[ -z $ROLE_ARN ]]; then
    ROLE_ARN=$(echo ${PROFILE_CONFIG} |  (grep 'role_arn*' || true) | sed -E 's/^.*role_arn *= *([^ ]*).*$/\1/')
fi

rm -f $TEMP_FILE

# if chrome is already open, we would get just new tab without our extensions,
# unless we use custom --user-data-dir
mkdir -p "$USER_DATA_DIR"

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --load-extension="$EXTENSION" --disable-extensions-except="$EXTENSION" \
    --user-data-dir="$USER_DATA_DIR" \
    'http://localhost/?durationHours='$DURATION_HOURS'&app='$APP_NAME'&filename='$(basename ${TEMP_FILE})'&roleArn='$ROLE_ARN 2>/dev/null &

while [ ! -f $TEMP_FILE ]; do
  sleep 1
done


if [ -e $AWS_CREDENTIALS ]; then
  cp $AWS_CREDENTIALS $AWS_CREDENTIALS.bak
  # delete section with old values, if any
  awk '/^\[/{keep=1} /^\['$PROFILE_NAME'\]/{keep=0} {if (keep) {print $0}}' $AWS_CREDENTIALS.bak > ${AWS_CREDENTIALS}
fi


# add new values
cat << EOL >> "${AWS_CREDENTIALS}"

[$PROFILE_NAME]
EOL

cat $TEMP_FILE >> "${AWS_CREDENTIALS}"

echo "Updated profile $PROFILE_NAME."
tail -1 ${AWS_CREDENTIALS}

trap cleanup EXIT
function cleanup() {
    # remove downmloaded tempfile
    rm -f ${TEMP_FILE}
    # kill this chrome
    kill $(ps ax | grep 'Chrome.app' | grep 'filename=temporary_aws_credentials' | awk '{ print $1; }')
}
