#! /bin/bash -

# This script generates the attestation authority json data. The file is 
# specified by environment variable.
#
# The environment variables come from Wercker environment. Should be set 
# before running script.
#
# GPG_SCRIPT
# ATTESTATION_AUTHORITY_FILE
#

ATTESTATION_AUTHORITY_TEMPLATE=$(cat <<EOF
[
    {
        "name":"@ATTESTATION_NAME@",
        "public_keys":["@ATTESTATION_KEY@"]
    }
]
EOF
)

if [ -z "${ATTESTATION_AUTHORITY_FILE}" ]; then
    echo "\"ATTESTATION_AUTHORITY_FILE\" not set, please set it." >&2
    exit 1
fi

name=$(${GPG_SCRIPT} --get-authority-names)
if [ $? -ne 0 -o -z "$name" ]; then
    echo "Failed to get the attestation authority name!"
    exit 1
fi

key=$(${GPG_SCRIPT} --get-authority-keyid "$name")
if [ $? -ne 0 -o -z "$key" ]; then
    echo "Failed to get key id for the attestation $name!"
    exit 1
fi

echo "${ATTESTATION_AUTHORITY_TEMPLATE}" | \
    sed -e 's!@ATTESTATION_NAME@!'"$name"'!' \
        -e 's!@ATTESTATION_KEY@!'"$key"'!' \
        >"${ATTESTATION_AUTHORITY_FILE}"
