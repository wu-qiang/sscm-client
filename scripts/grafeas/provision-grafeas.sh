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
    local proj="$1"
    if curl -s -X GET "$GRAFEAS_URL" | jq '.projects|.[]|.name' | grep -- "\"${proj}\"" > /dev/null ; then
        return 0
    fi
    return 1
}

grafeas_create_project() {
    local proj="$1"
    curl -s -X POST "$GRAFEAS_URL" -d "{\"name\":\"${proj}\"}" > /dev/null || return 1
    return 0
}

declare _iter=
declare _status=0

for _iter in $PROJECT_NAMES
do
    if grafeas_project_exists "$_iter" ; then
        echo "Grafeas project '$_iter' already exists"
    else
        echo "Creating Grafeas project '$_iter' ..."
        grafeas_create_project "$_iter"
        if ! grafeas_project_exists "$_iter" ; then
            echo "Couldn't create Grafeas project '$_iter'!"
            _status=1
        fi
    fi
done

exit $_status

