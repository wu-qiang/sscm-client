#!/bin/bash

#
# Script to provision project names into grafeas server
#

#
# Depends on the following environment variables:
#
# GRAFEAS_SERVER_ADDRESS
# GRAFEAS_SERVER_PORT
#

declare PROJECT_NAMES="projects/weblogic-kubernetes-operator projects/build-infrastructure"
declare GRAFEAS_URL="http://${GRAFEAS_SERVER_ADDRESS}:${GRAFEAS_SERVER_PORT}/v1alpha1/projects"

grafeas_project_exists() {
    local project="$1"
    if curl -s -X GET "$GRAFEAS_URL" | jq '.projects|.[]|.name' | grep -- "\"${project}\"" > /dev/null ; then
        return 0
    fi
    return 1
}

grafeas_create_project() {
    local project="$1"
    curl -s -X POST "$GRAFEAS_URL" -d "{\"name\":\"${project}\"}" > /dev/null || return 1
    return 0
}

provision_project_names() {
    local project=
    local status=0
    for project in $PROJECT_NAMES
    do
        if grafeas_project_exists "$project" ; then
            echo "Grafeas project '$project' already exists"
        else
            echo "Creating Grafeas project '$project' ..."
            grafeas_create_project "$project"
            if ! grafeas_project_exists "$project" ; then
                echo "Couldn't create Grafeas project '$project'!"
                ((status++))
            fi
        fi
    done
}

declare estatus=0

provision_project_names || ((estatus++))

exit $estatus

