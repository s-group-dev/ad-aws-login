#!/usr/bin/env bash 
set -euo pipefail

PROFILE_NAME=
APP_NAME=
DURATION_HOURS=4
ROLE_ARN=

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
        -d|--duration-hours)
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

if [ -z $PROFILE_NAME ]; then
    usage
fi

# Check that AWS config and selected profile exists.
AWS_CONFIG="${HOME}/.aws/config"
if [ ! -f "${AWS_CONFIG}" ]; then
    echo "AWS config file (${AWS_CONFIG}) does not exist. Cannot continue."
    exit 1
fi

if ! cat "${AWS_CONFIG}" | grep -q "^\[profile ${PROFILE_NAME}\]$"; then
    echo "Profile ${PROFILE_NAME} not found in ${AWS_CONFIG}."
    exit 2
fi

if [ -z $APP_NAME ]; then
    echo "--app-name not specified. Now you must select app manually."
fi

THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
EXTENSION="$THIS_DIR/chrome_extension"

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
TEMP_FILENAME=temporary_aws_credentials${TIMESTAMP}.txt
TEMP_FILE=~/Downloads/$TEMP_FILENAME
rm -f $TEMP_FILE

# if chrome is already open, we would get just new tab without our extensions,
# unless we use custom --user-data-dir
USER_DATA_DIR="$THIS_DIR/user_data"
mkdir -p "$USER_DATA_DIR"

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --load-extension="$EXTENSION" --disable-extensions-except="$EXTENSION" \
    --user-data-dir="$USER_DATA_DIR" \
    'http://localhost/?durationHours='$DURATION_HOURS'&app='$APP_NAME'&filename='$TEMP_FILENAME'&roleArn='$ROLE_ARN 2>/dev/null &

while [ ! -f $TEMP_FILE ]; do
  sleep 1
done


TARGET_FILE=~/.aws/credentials
if [ -e $TARGET_FILE ]; then
  cp $TARGET_FILE $TARGET_FILE.bak
  # delete section with old values, if any
  awk '/^\[/{keep=1} /^\['$PROFILE_NAME'\]/{keep=0} {if (keep) {print $0}}' $TARGET_FILE.bak > ${TARGET_FILE}
fi

# add new values
echo -e "\n[$PROFILE_NAME]" >> ${TARGET_FILE}
cat $TEMP_FILE >> ${TARGET_FILE}

echo "Updated profile $PROFILE_NAME."
tail -1 ${TARGET_FILE}

trap cleanup EXIT
function cleanup() {
    # remove downmloaded tempfile
    rm -f ${TEMP_FILE}
    # kill this chrome
    kill $(ps ax | grep 'Chrome.app' | grep 'filename=temporary_aws_credentials' | awk '{ print $1; }')
}
