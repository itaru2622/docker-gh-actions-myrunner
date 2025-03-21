SHELL  =/bin/bash
img   ?=itaru2622/gh-actions-myrunner-ubuntu:24.04
base  ?=ubuntu:24.04
cName ?=gh-action-runner

# personal access token for gh login, neeeded to onDemand exection outside github actions
GH_PAT ?=changeme

# params for configure.sh, registering this runner into github.
#   rName: runner Name to register github.
rName  ?=selfhost-ubuntu-24.04-amd64
#   label: labels to register github for this runner instance.
label  ?=amd64,ubuntu-24.04,ubuntu-latest,Linux,X64,self-hosted
#   rGroup: runner group, to make this runner instance belong
rGroup ?=Default

# rTarget: org|repo which this runner works for, and its scope(rScope).
#     rTarget   <=> rScope
# ----------------------------
#      ORG      <=> orgs
#      ORG/REPO <=> repos   
rTarget ?=changeme
# resolve rScope from rTaget
ifeq ($(findstring /,${rTarget}),/)
   rScope=repos
else
   rScope=orgs
endif
rScope  ?=orgs
rURL    ?=https://github.com/${rTarget}
rAPI    ?=/${rScope}/${rTarget}/actions/runners

RUNNER_ALLOW_RUNASROOT ?=false
ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT ?=1

# dirs
wDir       ?=${PWD}
runner_dir ?=/opt/gh-action-runner


cmd ?=make bootRunner -C /work

build:
	docker build --build-arg base=${base} --build-arg runner_dir=${runner_dir} -t ${img} .

# start container; systemd for DinD (isolated; no shar for docker.socket)
# SAMPLE: make startContainerWithSystemd   rTarget=     GH_PAT=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainerWithSystemd:
	docker run --name ${cName} --hostname ${cName} -d --restart always --user root  --privileged \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT=${GH_PAT} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} \
	-v ${wDir}:/work \
	${img} /lib/systemd/systemd --show-status=true

# start container; without systemd
# SAMPLE: make startContainer  rTarget=     GH_PAT=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainer:
	docker run --name ${cName} --hostname ${cName} -d --restart always \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT=${GH_PAT} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} \
        -v ${wDir}:/work \
        ${img} ${cmd}

# stop container
# SAMPLE: make stopContainer
stopContainer:
	docker rm -f ${cName}

# exec bash in container
# SAMPLE: make bash
bash:
	docker exec -it -u runner -w /work ${cName} /bin/bash

# ops within runner container: >>>>>>>

bootRunner: login config _runFG

# gh login/logout
# SAMPLE: make login
login:
	@echo ${GH_PAT} | gh auth login --with-token
	-gh auth status
# SAMPLE: make logout
logout:
	-gh auth logout

# SAMPLE: make runnerStart
runnerStart: config _run
#runnerStart: config _runsvc

# SAMPLE: make runnerStop
runnerStop:  unconfig _kill 
#runnerStop: unconfig _killsvc 

# SAMPLE: make config
config:
	$(eval url=${rURL})
	$(eval token=$(shell gh api --method POST ${rAPI}/registration-token | jq -r '.token'))
	(cd ${runner_dir}; config.sh --url ${url} --token ${token} --replace --name ${rName} --labels ${label} --runnergroup ${rGroup} --no-default-labels --disableupdate --unattended --ephemeral )
	-(cd ${runner_dir}; sudo ./svc.sh install runner )

# SAMPLE: make unconfig
unconfig:
	-(cd ${runner_dir}; sudo ./svc.sh uninstall; rm -f ./svc.sh )
	$(eval token=$(shell gh api --method POST ${rAPI}/remove-token | jq -r '.token'))
	(cd ${runner_dir}; ./config.sh remove --token ${token} )

_runsvc:
	(cd ${runner_dir}; sudo ./svc.sh start )
_run:
	(cd ${runner_dir}; ./run.sh --ephemeral & )
_runFG:
	(cd ${runner_dir}; ./run.sh --ephemeral )
_fakeDaemon:
	tail -f /dev/null

_killsvc:
	-(cd ${runner_dir}; sudo ./svc.sh stop )
_kill:
	-pkill -f ${runner_dir}/bin/Runner.Listener	
