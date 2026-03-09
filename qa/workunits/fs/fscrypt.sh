#!/usr/bin/env bash

set -xe

mydir=$(dirname "$0")

# Assumes fscrypt_cli_setup.sh has been called by the YAML file used to execute this script

if [ $# -ne 2 ]; then
    echo "2 parameters are required!"
    echo "Usage:"
    echo "  fscrypt.sh <none|unlocked|locked> <testcase>"
    echo "  testcase: the test workunit name"
    exit 1
fi

fscrypt_type=$1
test_case=$2
test_dir=fscrypt_test_${fscrypt_type}_${test_case}

# Ensure fscrypt CLI is installed and in PATH
FSCRYPT_CLI="$(type -P fscrypt)"
if [ -z "$FSCRYPT_CLI" ]; then
    echo "fscrypt CLI not found after setup. Ensure it was installed correctly."
    exit 1
fi

# Initialize global fscrypt config
sudo $FSCRYPT_CLI setup --force --verbose --all-users

MOUNT_POINT=$(dirname "$(dirname "$(pwd)")")
# Verify that the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Error: Current working directory '$MOUNT_POINT' is not a valid directory."
    exit 1
fi

# Create the test directory
test_dir="$MOUNT_POINT/$test_dir"
sudo mkdir "$test_dir"
sudo chmod 777 "$test_dir"
# Check the fscrypt status for the mount point
echo checking .fscrypt folder contents 
find "${MOUNT_POINT}/.fscrypt" || true
STATUS_OUTPUT=$(sudo $FSCRYPT_CLI status "$MOUNT_POINT" --verbose || true)
echo checking .fscrypt folder contents 
find "${MOUNT_POINT}/.fscrypt" || true
if echo "$STATUS_OUTPUT" | grep -q "users can create fscrypt metadata on this filesystem"; then
    echo "The mount point '$MOUNT_POINT' is already initialized with fscrypt."
else
    echo "The mount point '$MOUNT_POINT' is not properly initialized. Initializing now..."

    # Initialize fscrypt on the mount point
    echo checking .fscrypt folder contents 
    find "${MOUNT_POINT}/.fscrypt" || true
    if sudo $FSCRYPT_CLI setup "$MOUNT_POINT" --verbose --force --all-users; then
        echo "Successfully initialized fscrypt on '$MOUNT_POINT'."
    else
        echo "Error: Failed to initialize fscrypt on '$MOUNT_POINT'."
        exit 1
    fi
    echo checking .fscrypt folder contents 
    find "${MOUNT_POINT}/.fscrypt" || true
fi

case ${fscrypt_type} in
    "none")
        # Test non-encrypted directory
        pushd "$test_dir"
        "${mydir}/../suites/${test_case}.sh"
        popd
        ;;
    "unlocked")
        # Encrypt but leave unlocked the test directory
		printf "password\npassword\n" | sudo $FSCRYPT_CLI encrypt "$test_dir" --verbose --source=custom_passphrase  --name="test_secret"
        pushd "$test_dir"
        "${mydir}/../suites/${test_case}.sh"
        popd
        ;;
    "locked")
        # Encrypt and lock the directory
        echo checking .fscrypt folder contents 
        find "${MOUNT_POINT}/.fscrypt" || true
        printf "password\npassword\n" | sudo $FSCRYPT_CLI encrypt --skip-unlock "$test_dir" --verbose --source=custom_passphrase  --name="test_secret"
        pushd "$test_dir"
        echo checking .fscrypt folder contents 
        find "${MOUNT_POINT}/.fscrypt" || true
        "${mydir}/../suites/${test_case}.sh"
        popd
        ;;
    *)
        echo "Unknown parameter $1"
        exit 1
        ;;
esac
