#! /bin/bash -

# This script testthe provisioned policy Sphinx.

# The environment variables come from Wercker environment. Should be set before
# running script.
#
# GPG_SCRIPT
# SPHINX_ARS_ENDPOINT
# SPHINX_TMS_ENDPOINT
# SPHINX_CLIENT_ID
# SPHINX_CLIENT_SECRET
# SPHINX_SERVICE_NAME

SPHINX_REQUEST_TEMPLATE=$(cat <<EOF
{
    "serviceName": "${SPHINX_SERVICE_NAME:-grafeas}",
    "resource": "experimental",
    "action": "deploy",
    "attributes": [
        {
            "name": "attestations",
            "value": [@ATTESTATIONS@]
        }
    ]
}
EOF
)

names=($(${GPG_SCRIPT} --get-authority-names))
if [ $? -ne 0 -o ${#names[@]} -lt 1 ]; then
    echo "Failed to get the attestation authority names!" >&2
    exit 1
fi

tmsurl="${SPHINX_TMS_ENDPOINT:-https://a.authz.fun:6735/bak8dhbp5c8g00dbaup0/tenant-mgmt/v1/token}"
secret="${SPHINX_CLIENT_ID:-client-BDIuVS}:${SPHINX_CLIENT_SECRET:-eYHNuaFZBH}"
body=$(curl -s -f -X POST -d "grant_type=client_credentials" -u "$secret" "$tmsurl")
if [ $? -ne 0 ]; then
    echo "Failed to apply the Sphinx access token!" >&2
    return 1
fi
token=$(echo "$body" | jq -r '.access_token')

attestations=$(printf ',"%s"' ${names[@]})
arsurl="${SPHINX_ARS_ENDPOINT:-https://a.authz.fun:6734/bak8dhbp5c8g00dbaup0/authz-check/v1/is-allowed}"
cat <<EOF |
{
    "serviceName": "${SPHINX_SERVICE_NAME:-grafeas}",
    "resource": "experimental",
    "action": "deploy",
    "attributes": [
        {
            "name": "attestations",
            "value": [${attestations:1}]
        }
    ]
}
EOF
curl -X POST -d @- -H "Authorization: Bearer $token" "$arsurl"
