#!/usr/bin/env bash

set -Eeuo pipefail

_me=$0

# cleanup logic on error
catch() {
  code=$?
  echo "catch ERR (${code}) @ ${_me} and remove runner from github.com..." 1>&2
  make login unconfig logout -C /work
}

trap 'catch; exit 130' INT
trap 'catch; exit 143' TERM

# execute commands
$@ & wait $!
