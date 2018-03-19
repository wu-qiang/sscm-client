#! /bin/bash -

# This script is used as binary authorization. It loads metadata from grafeas
# server. Check the attestaion authority, signature verification, and send
# request to Sphinx to ask the final deployment decision.

# To run this script, below commands must be available:
# 1. curl: Used send HTTP request to Grafeas server and Sphinx server.
# 2. jq: Extract data from the JSON message.
# 3. pgp verification command: Signature verification

# Usage: ./sbas.sh <project> <resourceUrl> <clusterName>"
#   <project>        the project name, for example "build"
#   <resourceUrl>    the url of the artifact that to be deployed
#   <clusterName>    the target cluster name

# The content is defined in a separate JSON file.
# The file name is specified by environment variable "ATTESTATION_AUTHORITY_FILE".
# If not set "ATTESTATION_AUTHORITY_FILE", will not check attestation authority.
declare -A ATTESTATION_AUTHORITY

SPHINX_SERVICE_NAME="grafeas"
SPHINX_ARS_URL="https://a.authz.fun:6734/bak8dhbp5c8g00dbaup0/authz-check/v1/is-allowed"
SPHINX_TOKEN_URL="https://a.authz.fun:6735/bak8dhbp5c8g00dbaup0/tenant-mgmt/v1/token"
SPHINX_SECRET="client-BDIuVS:eYHNuaFZBH"

SPHINX_REQUEST_TEMPLATE=$(cat <<EOF
{
    "serviceName": "${SPHINX_SERVICE_NAME}",
    "resource": "@CLUSTER_NAME@",
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

ATTESTATIONS=()
SIGNATURES=()
PGP_KEYIDS=()

# Load attestation authorities definition from JSON file.
# If not want to check attestation authority, please NOT set the enviroment 
# varaible "ATTESTATION_AUTHORITY_FILE".
loadAuthorities() {
    echo "Load Attestation Authoritoes from JSON file" >&2
    if [ -z "${ATTESTATION_AUTHORITY_FILE}" ]; then
        echo "\"ATTESTATION_AUTHORITY_FILE\" not set, authority check will be skipped." >&2
        return 0
    fi
    if [ ! -f "${ATTESTATION_AUTHORITY_FILE}" ]; then
        echo "Can't read the file \"${ATTESTATION_AUTHORITY_FILE}\"!" >&2
        return 1
    fi

    local data=$(cat "${ATTESTATION_AUTHORITY_FILE}")
    local count=$(echo "$data" | jq '. | length')
    local name keys
    for (( i=0; i<$count; i++ )); do
        name=$(echo "$data" | jq -r '.['$i'].name | select (.!=null)')
        if [ $? -ne 0 -o -z "$name" ]; then
            echo "Failed extract authority name, invalid data: $data!" >&2
            return 1
        fi

        keys=$(echo "$data" | jq -r '.['$i'].public_keys | join(" ")')
        if [ $? -ne 0 ]; then
            echo "Failed extract authority public keys, invalid data: $data!" >&2
            return 1
        fi

        ATTESTATION_AUTHORITY[$name]=$keys
    done
}

# Read occurrences and notes from grafeas and extract values.
loadMetadata() {
    echo "Get all occurrences from Grafeas server" >&2
    local occurrencesUrl="${GRAFEAS_ENDPOINT}/v1alpha1/projects/${PROJECT_NAME}/occurrences"
    local body count items
    body=$(curl -s -f "$occurrencesUrl")
    if [ $? != 0 ]; then
        echo "Failed get occurrences from \"$occurrencesUrl\"!" >&2
        return 1
    fi
    count=$(echo "$body" | jq '.occurrences | length')
    if [ $count -lt 1 ]; then
        echo "Not found occurrence for the project \"${PROJECT_NAME}\"!" >&2
        return 1
    fi

    echo "Filter the occurrences with resourceUrl" >&2
    items=$(echo "$body" | jq -c '.occurrences | [ .[] | select(.resourceUrl=="'"${RESOURCE_URL}"'") ]')
    count=$(echo "$items" | jq '. | length')
    if [ $count -lt 1 ]; then
        echo "Not found occurrence for the resourceUrl \"${RESOURCE_URL}\"!" >&2
        return 1
    fi

    echo "Extract signatures and note name from occurrences" >&2
    for (( i=0; i<$count; i++ )); do
        local item=$(echo "$items" | jq -c ".[$i]")
        if ! extractAttestation "$item"; then
            return 1
        fi
    done
}

extractAttestation() {
    local data="$1"

    local signature=$(echo "$data" | jq -r '.attestationDetails.pgpSignedAttestation.signature | select (.!=null)')
    local keyid=$(echo "$data" | jq -r '.attestationDetails.pgpSignedAttestation.pgpKeyId | select (.!=null)')

    echo "keyid=$keyid"
    # some occurrences may have no signature, it's valid. skip this kind occurrence directly.
    if [ -z "$signature" -a -z "$keyid" ]; then
        return 0
    fi
    # signature and key id must exist at the same time.
    if [ -z "$signature" -o -z "$keyid" ]; then
        echo "No signature or keyid or noteName, invalid occurrence: $data" >&2
        return 1
    fi

    local noteName=$(echo "$data" | jq -r '.noteName | select (.!=null)')
    if [ -z "$noteName" ]; then
        echo "Not found noteName, invalid occurrence: $data" >&2
        return 1
    fi

    local noteUrl="$GRAFEAS_ENDPOINT/v1alpha1/$noteName"
    local body
    body=$(curl -s -f "$noteUrl")
    if [ $? != 0 ]; then
        echo "Failed get note from $occurrencesUrl" >&2
        return 1
    fi
    local attestation=$(echo "$body" | jq -r '.attestationAuthority.hint.humanReadableName | select (.!=null)')
    if [ -z "$attestation" ]; then
        echo "Not get attestation, invalid note: \"$noteName\"!" >&2
        return 1
    fi

    ATTESTATIONS+=("$attestation") 
    SIGNATURES+=("$signature")
    PGP_KEYIDS+=("$keyid")
}

# Execute the binary authorization.
binaryAuthorize() {
    local count=${#PGP_KEYIDS[@]}

    echo "Check the signature with key" >&2
    for (( i=0; i<$count; i++ )); do
        local key="${PGP_KEYIDS[$i]}" signature="${SIGNATURES[$i]}" 
        if ! checkSignature "$key" "$signature"; then
            return 1
        fi
    done

    echo "Check the attestation authority" >&2
    for (( i=0; i<$count; i++ )); do
        local key="${PGP_KEYIDS[$i]}" attestation="${ATTESTATIONS[$i]}"
        if ! checkAuthority "$key" "$attestation"; then
            return 1
        fi
    done
}

checkAuthority() {
    local key="$1" attestation="$2"

    # No authories data, skip authority check.
    if [ ${#ATTESTATION_AUTHORITY[@]} -eq 0 ]; then
        return 0
    fi

    val=${ATTESTATION_AUTHORITY["$attestation"]}
    if [[ ! "$val" =~ .*$key.* ]]; then
        echo "The key id \"$key\" doesn't match the attestation \"$attestation\"!" >&2
        return 1
    fi
}

checkSignature() {
    local key="$1" signature="$2"

    if ! ${GPG_SCRIPT} --verify "$signature"; then
        echo "Verify signature failed for the key \"$key\"!" >&2
        return 1
    fi

    local signKey=$(${GPG_SCRIPT} --get-signature-keyid "$signature")
    if [ X"$key" != X"$signKey" ]; then
        echo "The signture declare it's signed by \"$key\", but is \"$signKey\"" >&2
        return 1
    fi
}

# Provide request attributes get policy decison from Sphinx.
evaluatePolicy() {
    echo "Apply access token from Sphinx server" >&2
    local body
    body=$(curl -s -f -X POST -d "grant_type=client_credentials" -u "${SPHINX_SECRET}" "${SPHINX_TOKEN_URL}")
    if [ $? -ne 0 ]; then
        echo "Failed to apply the Sphinx access token!" >&2
        return 1
    fi
    local token=$(echo "$body" | jq -r '.access_token')

    echo "Get deploy decision from Sphinx server" >&2
    attestations=$(printf ',"%s"' ${ATTESTATIONS[@]})
    request=$(echo "$SPHINX_REQUEST_TEMPLATE" | sed -e 's!@CLUSTER_NAME@!'"$CLUSTER_NAME"'!' -e 's!@ATTESTATIONS@!'"${attestations:1}"'!')
    body=$(curl -s -f -X POST -H "Authorization: Bearer $token" -d "$request" "${SPHINX_ARS_URL}")
    if [ $? -ne 0 ]; then
        echo "Failed to execute Sphinx policy check!" >&2
        return 1
    fi

    result=$(echo $body | jq -r '.allowed')
    if [ X"$result" != X"true" ]; then
        echo "Sphinx deny this deployment request!" >&2
        return 1
    fi
}

#### The entrypoint of this script.

if [ $# -ne 3 ]; then
    echo "Usage: $0 <grafeas> <project> <resourceUrl> <clusterName>" >&2
    exit 2
fi

PROJECT_NAME="$1"
RESOURCE_URL="$2"
CLUSTER_NAME="$3"

GRAFEAS_ENDPOINT="http://${GRAFEAS_SERVER_ADDRESS}:{$GRAFEAS_SERVER_PORT}"
if [ -z "${GRAFEAS_ENDPOINT}" ]; then
    echo "Not get Grafeas endpoint, please check the environment variables \"GRAFEAS_SERVER_ADDRESS\" and \"GRAFEAS_SERVER_PORT\"!"
    exit 2
fi

if ! loadAuthorities; then
    echo "false"
    exit 1
fi

if ! loadMetadata; then
    echo "false"
    exit 1
fi

if ! binaryAuthorize; then
    echo "false"
    exit 1
fi

if ! evaluatePolicy; then
    echo "false"
    exit 1
fi

echo "true"
