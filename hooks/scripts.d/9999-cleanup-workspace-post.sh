#!/usr/bin/env bash
set -Eeuo pipefail

_me=$0

trap catch ERR
catch() {
  echo "Trap ERR ${_me} ! But exit 0 for run job"
  exit 0
}

echo "script kicked >>>>>>>>>>>>>>>>>>>>>>>"
echo "$0 $@"
echo "script kicked <<<<<<<<<<<<<<<<<<<<<<<"

echo "cleanup ${GITHUB_WORKSPACE} ------"
(cd / ; rm -rf ${GITHUB_WORKSPACE}; )

echo "cleanup: ${RUNNER_TEMP} -----------------------"
(cd / ; rm -rf ${RUNNER_TEMP}; )

echo "${_me} done #########################"
