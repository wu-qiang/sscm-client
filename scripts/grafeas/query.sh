#!/bin/bash

getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "I’m sorry, `getopt --test` failed in this environment."
    exit 1
fi

OPTIONS=hvp:n:o:s:
LONGOPTIONS=help,verbose,project:,note:,occurrence:,select:

# -temporarily store output to be able to check for errors
# -e.g. use “--options” parameter by name to activate quoting/enhanced mode
# -pass arguments only via   -- "$@"   to separate them correctly
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            help=1
            shift
            ;;
        -p|--project)
            project="$2"
            shift 2
            ;;
        -n|--note)
            note="$2"
            shift 2
            ;;
        -v|--verbose)
            verbose=1
            shift
            ;;
        -o|--occurrence)
            occurrence="$2"
            shift 2
            ;;
        -s|--select)
            select="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

if [ "$help" == 1 ]; then
  echo "CLI tool to query metadata from Grafeas Server"
  echo "Usage: query.sh [options] GRAFEAS_SERVER_URL"
  echo "GRAFEAS_SERVER_URL - http URL for the Grafeas Server for example http://localhost:8080"
  echo "OPTIONS"
  echo -e "\t--project or -p Name of project or the wildcard '*'"
  echo -e "\t--note or -n Name of the note to find in a given project or '*'"
  echo -e "\t--occurrence or -o Name of the occurrence or '*'"
  echo -e "\t--select or -s Select criteria for the JSON object field using a dot limited notation. See examples below."
  echo -e '\t  query.sh -v -p "weblogic-kubernetes-operator" -o "*" -s ".kind == \\"PACKAGE_VULNERABILITY\\"" $GRAFEAS_URL'
  echo -e '\t  query.sh -v -p "weblogic-kubernetes-operator" -o "*" -s ".vulnerabilityDetails.severity == \\"HIGH\\"" $GRAFEAS_URL'
  echo -e '\t  query.sh -v -p "weblogic-kubernetes-operator" -o "*" -s ".name | contains(\\"SecurityScan\\")" $GRAFEAS_URL'
  echo -e "\t--verbose or -v"
  echo -e "\t--help or -h"
  exit
fi

# handle non-option arguments
if [[ $# -ne 1 ]]; then
    echo "$0: The required parameters for the query options are not specified."
    exit 4
fi

if [ "$verbose" == 1 ]; then
  echo "Executing query with the following options --verbose:$verbose, project:$project, note:$note, occurrence:$occurrence, select: $select url:$1"
fi

query=$1/v1alpha1/projects
filter="."

if [ "$project" == "*" ]; then
 project="" 
fi

if [ -n "$project" ]; then
  query=$query/$project
  # Build query for notes
  if [ -n "$note" ]; then
    query=$query/notes
    if [ "$note" != "*" ]; then
      query=$query/$note
    else
      filter=".notes"
    fi 
  fi
  # Build query for occurrences
  if [ -n "$occurrence" ]; then
    query=$query/occurrences
    if [ "$occurrence" != "*" ]; then
      query=$query/$occurrence
    else
      filter=".occurrences"
    fi 
  fi
else
  filter=".projects"
fi

if [ -n "$select" ]; then
  # '| .[] select(.kind == "PACKAGE_VULNERABILITY")' 
  filter="'$filter[] | select($select)'"
fi


if [ "$verbose" == 1 ]; then
  echo "Invoking curl -X GET $query | jq $filter"
fi

echo 'Results:'
curl -X GET $query 2>/dev/null | eval jq "$filter"

