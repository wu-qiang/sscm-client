#! /bin/bash -

# Provision the policy for demo in Sphinx side.

# The environment variables come from Wercker environment. Should be set before
# running script.
#
# GPG_SCRIPT
# SPHINX_PMS_ENDPOINT
# SPHINX_PMS_TOKEN
# SPHINX_SERVICE_NAME
#

KAUCTL_CMD="$(cd $(dirname $0); pwd)/kauctl"
PMS_TOKEN="${SPHINX_PMS_TOKEN:-1489ad07d5b0b0ebcb0b43429e918fd0a8d09636f2d81ab328ca9faee587be92}"
SERVICE_NAME="${SPHINX_SERVICE_NAME:-grafeas}"

POLICY_TEMPLATE="grant role anonymous_role deploy @CLUSTER_NAME@ if IsSubSet((@ATTESTATIONS@), attestations)"

# Get attestations with GPG_SCRIPT, generate the policy content.
names=($(${GPG_SCRIPT} --get-authority-names))
if [ $? -ne 0 -o ${#names[@]} -lt 1 ]; then
    echo "Failed to get the attestation authority names!" >&2
    exit 1
fi

prodAttestations=$(printf ",'%s'" ${names[@]})
prodPolicy=$(echo "$POLICY_TEMPLATE" | sed -e 's!@CLUSTER_NAME@!production!' -e 's!@ATTESTATIONS@!'"${prodAttestations:1}"'!')

excluded=("projects/build-infrastructure/attestationAuthorities/SecurityScan")
expAttestations=$(printf ",'%s'" ${names[@]/$excluded})
expPolicy=$(echo "$POLICY_TEMPLATE" | sed -e 's!@CLUSTER_NAME@!experimental!' -e 's!@ATTESTATIONS@!'"${expAttestations:1}"'!')

"${KAUCTL_CMD}" config pms-endpoint "${SPHINX_PMS_ENDPOINT:-https://a.authz.fun:6733/bak8dhbp5c8g00dbaup0/policy-mgmt/v1/}"
 
# The command won't fail if the service doesn't exist.
echo "Clear the service" >&2
if ! "${KAUCTL_CMD}" --token="${PMS_TOKEN}" delete service "${SERVICE_NAME}"; then
    echo "Failed to remove the Sphinx service \"${SERVICE_NAME}\"!" >&2
    exit 1
fi
 
echo "Create the service for policy provision" >&2
if ! "${KAUCTL_CMD}" --token="${PMS_TOKEN}" create service "${SERVICE_NAME}"; then
    echo "Failed to create the Sphinx service \"${SERVICE_NAME}\"!" >&2
    exit 1
fi
 
echo "Create policy for production cluster" >&2
echo "The policy defintion: $prodPolicy" >&2
if ! "${KAUCTL_CMD}" --token="${PMS_TOKEN}" create policy --service-name="${SERVICE_NAME}" -c "$prodPolicy"; then
    echo "Failed to create the Sphinx policy for production cluster!" >&2
    exit 1
fi

echo "Create policy for experimental cluster" >&2
echo "The policy definition: $expPolicy" >&2
if ! "${KAUCTL_CMD}" --token="${PMS_TOKEN}" create policy --service-name="${SERVICE_NAME}" -c "$expPolicy"; then
    echo "Failed to create the Sphinx policy for experimental cluster!" >&2
    exit 1
fi
