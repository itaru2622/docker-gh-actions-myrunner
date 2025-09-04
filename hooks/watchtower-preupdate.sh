#!/usr/bin/env bash

# watchtower integration: when exit with non-Zero, watchtower will skip image updating.  refer below for details:
#  - https://github.com/containrrr/watchtower/issues/499
#  - https://github.com/containrrr/watchtower/blob/main/docs/lifecycle-hooks.md

# status.job-running is exist while job running powered by ACTIONS_RUNNER_HOOK_JOB_STARTED and ACTIONS_RUNNER_HOOK_JOB_COMPLETED
# in current implementaion, hooks/{job-started.sh, job-completed.sh} achieve it.

sDir=$(dirname $0)

if [ -e ${STATUS_JOB_RUNNING} ]; then
# do not update image while running.
   exit 1
fi

# going to update container image

# make container unregiter from github.
make login unconfig logout -C ${sDir}/..
exit 0
