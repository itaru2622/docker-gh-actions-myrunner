#!/usr/bin/env bash
set -Eeuo pipefail

echo "script kicked >>>>>>>>>>>>>>>>>>>>>>>"
echo "$0 $@"
echo "script kicked <<<<<<<<<<<<<<<<<<<<<<<"

_me=$0

# exit 0 always even some error found, to passthrough steps...
trap catch ERR
catch() {
  echo "Trap ERR ${_me}! But exit 0 for run job"
  exit 0
}

sDir=$(dirname $0)
echo "cDir: ${sDir}-----------------------"
#-------------------
for s in `ls ${sDir}/scripts.d/*-pre*.sh | sort -f`
do
   echo "${s} found then kick"
   ${s}
done
echo "${_me} done #########################"
