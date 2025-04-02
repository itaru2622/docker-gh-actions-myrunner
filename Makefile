SHELL  =/bin/bash
img   ?=itaru2622/gh-actions-myrunner:ubuntu24.04
base  ?=ubuntu:24.04
cName ?=gh-action-runner

# personal access token for gh login, neeeded to onDemand exection outside github actions
GH_PAT_RUNNER ?=changeme

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

# tool versions(tags) to use
runner_ver ?=$(shell curl -sL https://api.github.com/repos/actions/runner/releases/latest                 | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')
hook_ver   ?=$(shell curl -sL https://api.github.com/repos/actions/runner-container-hooks/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')
mgc_ver    ?=$(shell curl -sL https://api.github.com/repos/microsoftgraph/msgraph-cli/releases/latest     | grep tag_name | cut -d '"' -f 4 | sed 's/^v//')

build:
	docker build --build-arg base=${base} --build-arg runner_ver=${runner_ver} --build-arg hook_ver=${hook_ver} --build-arg mgc_ver=${mgc_ver} --build-arg runner_dir=${runner_dir} -t ${img} .

# start container; dockerd for DinD (isolated; no share for docker.socket)
# SAMPLE: make startContainerWithDockerd   rTarget=     GH_PAT_RUNNER=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainerWithDockerd:
	docker run --name ${cName} --hostname ${cName} -d --restart always --privileged \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT_RUNNER=${GH_PAT_RUNNER} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} \
	-v ${wDir}:/work:ro \
	${img} make bootRunnerDinD -C /work

# start container; without dockerd
# SAMPLE: make startContainer  rTarget=     GH_PAT_RUNNER=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainer:
	docker run --name ${cName} --hostname ${cName} -d --restart always \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT_RUNNER=${GH_PAT_RUNNER} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} \
        -v ${wDir}:/work:ro \
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

bootRunner: login config _runFG unconfig logout
bootRunnerDinD:: _startDiD _waitforDockerd bootRunner _cleanupDiD

_startDiD: /var/run/docker.sock
/var/run/docker.sock:
	sudo /usr/bin/dockerd &
_waitforDockerd:
	sleep 3
	/work/waitforDockerd.sh
_cleanupDiD:
	-docker ps -qa | xargs docker rm -f
	-docker images -qa | xargs docker rmi -f
	-docker system prune -f
	-docker volume prune -f
	-docker network prune -f
	-sudo pkill -f /usr/bin/dockerd
	-sudo rm -f /var/run/docker.pid /var/run/docker.sock
	sync
	sleep 2

# gh login/logout
# SAMPLE: make login
login:
	@echo ${GH_PAT_RUNNER} | gh auth login --with-token
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
