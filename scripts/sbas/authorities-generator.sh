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
    {
        "name":"@ATTESTATION_NAME@",
        "public_keys":["@ATTESTATION_KEY@"]
EOF
)

if [ -z "${ATTESTATION_AUTHORITY_FILE}" ]; then
    echo "\"ATTESTATION_AUTHORITY_FILE\" not set, please set it." >&2
    exit 1
fi

# TODO Support more than one attestation.
names=$(${GPG_SCRIPT} --get-authority-names)
if [ $? -ne 0 -o -z "$names" ]; then
    echo "Failed to get the attestation authority names!" >&2
    exit 1
fi

rm -f "${ATTESTATION_AUTHORITY_FILE}"
echo "[" > "${ATTESTATION_AUTHORITY_FILE}"

first_time=true
for name in $names
do
    key=$(${GPG_SCRIPT} --get-authority-keyid "$name")
    if [ $? -ne 0 -o -z "$key" ]; then
        echo "Failed to get key id for the attestation $name!" >&2
        exit 1
    fi

    if [[ ! -n "$first_time" ]] ; then
        echo "    }," >> "${ATTESTATION_AUTHORITY_FILE}"
    else
        first_time=
    fi
    echo "${ATTESTATION_AUTHORITY_TEMPLATE}" | \
        sed -e 's!@ATTESTATION_NAME@!'"$name"'!' \
            -e 's!@ATTESTATION_KEY@!'"$key"'!' \
            >> "${ATTESTATION_AUTHORITY_FILE}"
done

echo "    }" >> "${ATTESTATION_AUTHORITY_FILE}"
echo "]" >> "${ATTESTATION_AUTHORITY_FILE}"

