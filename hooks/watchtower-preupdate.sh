#!/usr/bin/env bash

# watchtower integration: when exit with non-Zero, watchtower will skip image updating.  refer below for details:
#  - https://github.com/containrrr/watchtower/issues/499
#  - https://github.com/containrrr/watchtower/blob/main/docs/lifecycle-hooks.md

# status.job-running is exist while job running powered by ACTIONS_RUNNER_HOOK_JOB_STARTED and ACTIONS_RUNNER_HOOK_JOB_COMPLETED
# in current implementaion, hooks/{job-started.sh, job-completed.sh} achieve it.

sDir=$(dirname $0)

skip=0
if [ -e ${sDir}/status.job-running ]; then
   skip=1
fi
exit ${skip}
