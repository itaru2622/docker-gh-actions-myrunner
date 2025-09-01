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

gh auth logout | cat

echo "${_me} done #########################"
