#!/usr/bin/env bash
set -Eeuo pipefail

_me=$0

# exit 0 always even some error catched.
trap catch ERR
catch() {
  code=$?
  echo "catch ERR (${code}) @ ${_me} and ignored" 1>&2
  exit 0
}

rm -f ${STATUS_JOB_RUNNING}

sDir=$(dirname $0)
for s in `ls ${sDir}/scripts.d/*-post*.sh |  sort -f`
do
   ${s}
done

echo " ${_me} done #########################"
