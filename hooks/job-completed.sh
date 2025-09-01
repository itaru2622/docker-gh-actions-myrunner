#!/usr/bin/env bash
set -Eeuo pipefail

echo "script kicked >>>>>>>>>>>>>>>>>>>>>>>"
echo "$0 $@"
echo "script kicked <<<<<<<<<<<<<<<<<<<<<<<"

_me=$0

# exit 0 always even some error found, to passthrough steps...
trap catch ERR
catch() {
  echo "Trap ERR ${_me} ! But exit 0 for run job" 1>&2
  exit 0
}

rm -f ${STATUS_JOB_RUNNING}
sDir=$(dirname $0)

echo "sDir: ${sDir}-----------------------"
for s in `ls ${sDir}/scripts.d/*-post*.sh |  sort -f`
do
   echo "${s} found then kick"
   ${s}
done

echo " ${_me} done #########################"
