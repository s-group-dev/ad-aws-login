#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME=
APP_NAME=
DURATION_HOURS=4
ROLE_ARN=

function usage() {
    echo "Usage: ad-aws-login.sh --profile <profile name> --app <app name>"
    echo "Options:"
    echo "  --profile  The name of the profile in ~/.aws/credentials to update"
    echo "  --app A substring of the app name shown in myapps.microsoft.com to launch."
    echo "        Case-insensitive. Must be url encoded (replace spaces with %20)."
    echo "  --duration-hours How long the temporary credentials are valid"
    echo "  --role-arn AWS IAM Role to assume with AD credentials"
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
    echo "Must specify profile name."
    usage
fi

if [ -z $APP_NAME ]; then
    echo "--app-name not specified. Now you must select app manually."
fi

THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
EXTENSION=$THIS_DIR/chrome_extension

TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
TEMP_FILENAME=temporary_aws_credentials${TIMESTAMP}.txt
TEMP_FILE=~/Downloads/$TEMP_FILENAME
rm -f $TEMP_FILE

# if chrome is already open, we would get just new tab without our extensions,
# unless we use custom --user-data-dir
USER_DATA_DIR=$THIS_DIR/user_data
mkdir -p $USER_DATA_DIR

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --load-extension=$EXTENSION --disable-extensions-except=$EXTENSION \
    --user-data-dir=$USER_DATA_DIR \
    'http://localhost/?durationHours='$DURATION_HOURS'&app='$APP_NAME'&filename='$TEMP_FILENAME'&roleArn='$ROLE_ARN 2>/dev/null &

PID=$!

while [ ! -f $TEMP_FILE ]
do
  sleep 1
done

# kill this chrome
kill $PID

TARGET_FILE=~/.aws/credentials
if [ -e $TARGET_FILE ]; then
  cp $TARGET_FILE $TARGET_FILE.bak
  # delete section with old values, if any
  awk '/^\[/{keep=1} /^\['$PROFILE_NAME'\]/{keep=0} {if (keep) {print $0}}' $TARGET_FILE.bak > ${TARGET_FILE}
fi
# add new values
echo "\n[$PROFILE_NAME]" >> ${TARGET_FILE}
cat $TEMP_FILE >> ${TARGET_FILE}
rm $TEMP_FILE

echo "Updated profile $PROFILE_NAME."
tail -1 ${TARGET_FILE}
