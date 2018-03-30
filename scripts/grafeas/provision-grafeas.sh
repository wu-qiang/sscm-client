#!/bin/bash

#
# Script to provision project names and attestation
# authorities into grafeas server
#
# host:port for grafeas server passed as $1
#

declare GRAFEAS_PROJECTS_URL=
declare GRAFEAS_NOTES_URL=

declare PROJECT_NAMES="projects/weblogic-kubernetes-operator projects/build-infrastructure"
declare AUTHORITY_NAMES="Build Test SecurityScan"

if [[ -n "$1" ]] ; then
    GRAFEAS_PROJECTS_URL="http://${1}/v1alpha1/projects"
    echo "GRAFEAS_PROJECTS_URL set to '$GRAFEAS_PROJECTS_URL'"
    GRAFEAS_NOTES_URL="http://${1}/v1alpha1/projects/build-infrastructure/notes"
    echo "GRAFEAS_NOTES_URL set to '$GRAFEAS_NOTES_URL'"
else
    echo "Grafeas host:port not provided!"
    exit 1
fi

project_exists() {
    curl -s -X GET "$GRAFEAS_PROJECTS_URL" | jq -e ".projects|.[]|select(.name == \"${1}\")" > /dev/null
}

create_project() {
    curl -s -X POST "$GRAFEAS_PROJECTS_URL" -d "{\"name\":\"${1}\"}" > /dev/null
}

provision_project_names() {
    local project=
    local status=0
    for project in $PROJECT_NAMES
    do
        if project_exists "$project" ; then
            echo "Grafeas project '$project' already exists"
        else
            echo "Creating Grafeas project '$project' ..."
            create_project "$project"
            if [[ $? -ne 0 ]] || ! project_exists "$project" ; then
                echo "Couldn't create Grafeas project '$project'!"
                ((status++))
            fi
        fi
    done
}

authority_exists() {
    local note_name="projects/build-infrastructure/notes/${1}AttestationAuthority"
    curl -s -X GET "$GRAFEAS_NOTES_URL" | jq -e ".notes|.[]|select(.name == \"${note_name}\")" > /dev/null
}

create_authority() {
    local note_name="projects/build-infrastructure/notes/${1}AttestationAuthority"
    local short_desc="build-infrastructure:${1}"
    local long_desc="Oracle Grafeas ${1} Metadata Generator"
    local authority_name="projects/build-infrastructure/attestationAuthorities/${1}"

    curl -s -X POST -d @- "$GRAFEAS_NOTES_URL" <<EOF > /dev/null
    {
        "name": "${note_name}",
        "shortDescription": "${short_desc}",
        "longDescription": "${long_desc}",
        "kind": "ATTESTATION_AUTHORITY",
        "attestationAuthority": {
            "hint": {
                "humanReadableName": "${authority_name}"
            }
        }
    }
EOF
}

provision_authorities() {
    local authority=
    local status=0
    for authority in $AUTHORITY_NAMES
    do
        if authority_exists "$authority" ; then
            echo "Attestation authority for '$authority' already exists"
        else
            echo "Creating attestation authority for '$authority' ..."
            create_authority "$authority"
            if [[ $? -ne 0 ]] || ! authority_exists "$authority" ; then
                echo "Couldn't create attestation authority for '$authority'!"
                ((status++))
            fi
        fi
    done
}

declare estatus=0

provision_project_names || ((estatus++))
provision_authorities || ((estatus++))

exit $estatus

