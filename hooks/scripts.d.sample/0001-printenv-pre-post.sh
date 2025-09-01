#!/usr/bin/env bash
set -Eeuo pipefail

_me=$0

trap catch ERR
catch() {
  echo "Trap ERR ${_me} ! But exit 0 for run job" 1>&2
  exit 0
}

echo "script kicked >>>>>>>>>>>>>>>>>>>>>>>"
echo "$0 $@"
echo "script kicked <<<<<<<<<<<<<<<<<<<<<<<"

echo "env: excepts sensitive(pass|token|pat|cred)-----------------------"
env | sort -u -f | grep -i -v -e pass -e token -e pat -e cred

echo "env: sensitive(pass|token|pat|cred)-----------------------"
env | sort -u -f | grep -i -e pass -e token -e pat -e cred | awk -F= '{print $1 "=****"}'

echo "files: ${PWD} -----------------------"
ls -lrta

echo "files: ${RUNNER_TOOL_CACHE} -----------------------"
ls -lrta ${RUNNER_TOOL_CACHE}

echo "files: ${RUNNER_TEMP} -----------------------"
ls -lrta ${RUNNER_TEMP}

echo "github event: ${GITHUB_EVENT_PATH} -----------------------"
cat ${GITHUB_EVENT_PATH} | yq -y

echo "${_me} done #########################"
