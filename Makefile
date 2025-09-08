SHELL  =/bin/bash
img   ?=itaru2622/gh-actions-myrunner:ubuntu24.04
base  ?=ubuntu:24.04
cName ?=gh-action-runner
pull  ?=missing

# personal access token for gh login, neeeded to onDemand exection outside github actions
GH_PAT_RUNNER ?=changeme

# params for configure.sh, registering this runner into github.
#   label: labels to register github for this runner instance.
label  ?=amd64,ubuntu-24.04,ubuntu-latest,Linux,X64,self-hosted
#   rGroup: runner group, to make this runner instance belong
rGroup ?=Default
#   rName: runner Name to register github.
rName  ?=selfhost-ubuntu-24.04-amd64

# ajust rName, replace @@HOSTNAME@@ to hostname, as scaling consideration(replicas) to fix below gaps:
#  @github: each runner instance needs to be config.sh with unique name(--name ${rName}) to work.
#  @replica with docker-compose: it cannot specify replica's hostname before boot
#  then, it needs to adjust at runtime.
ifeq (@@HOSTNAME@@,$(findstring @@HOSTNAME@@,$(rName)))
override rName:=$(subst @@HOSTNAME@@,$(shell hostname),$(rName))
endif

# rTarget: org|repo which this runner works for, and its scope(rScope).
#     rTarget   <=> rScope
# ----------------------------
#      ORG      <=> orgs
#      ORG/REPO <=> repos   
#      ENTERPRISE <=> enterprises
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
rConfigOpts ?=--replace --no-default-labels --disableupdate --unattended --ephemeral

RUNNER_ALLOW_RUNASROOT ?=false
ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT ?=1


# dirs
wDir       ?=$(shell pwd)
runner_dir ?=/opt/gh-action-runner

# keep some seconds for container management...
WAIT_MAINTAIN_TEST ?=10

# cmd: what to do in container (boot.sh catches signal(INT|TERM) and unconfig runner from github.com )
cmd ?=boot.sh make bootRunner -C /work
cmd ?=boot.sh make bootRunnerDinD -C /work

build:
	docker build --build-arg base=${base} --build-arg runner_dir=${runner_dir} -t ${img} .

# start container; dockerd for DinD (isolated; no share for docker.socket)
# SAMPLE: make startContainerWithDockerd   rTarget=     GH_PAT_RUNNER=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainerWithDockerd:
	docker run --name ${cName} --hostname ${cName} -d --restart always --privileged --pull ${pull} \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT_RUNNER=${GH_PAT_RUNNER} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} -e rURL=${rURL} -e rAPI=${rAPI} -e rConfigOpts="${rConfigOpts}" \
	-v /etc/resolv.conf:/etc/resolv.conf:ro \
	-v ${wDir}:/work:ro -w /work \
	${img} ${cmd}

# start container; without dockerd
# SAMPLE: make startContainer  rTarget=     GH_PAT_RUNNER=
#       -e ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh -e ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
startContainer:
	docker run --name ${cName} --hostname ${cName} -d --restart always --pull ${pull} \
	-e ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=${ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT} \
	-e RUNNER_ALLOW_RUNASROOT=${RUNNER_ALLOW_RUNASROOT} \
	-e GH_PAT_RUNNER=${GH_PAT_RUNNER} \
	-e rTarget=${rTarget} -e rScope=${rScope} -e rName=${rName} -e label=${label} -e rGroup=${rGroup} -e rURL=${rURL} -e rAPI=${rAPI} -e rConfigOpts="${rConfigOpts}" \
        -v ${wDir}:/work:ro -w /work \
        ${img} ${cmd}

# stop container
# SAMPLE: make stopContainer
stopContainer:
	docker rm -f ${cName}

# exec bash in container
# SAMPLE: make bash
bash:
	docker exec -it ${cName} /bin/bash

# ops within runner container: >>>>>>>

bootRunner: toolcache login config logout _runFG login2 unconfig logout
bootRunnerDinD: _startDiD _waitforDockerd bootRunner _cleanupDiD

/var/run/docker.sock: _startDiD
_startDiD:
	/usr/bin/dockerd &
_waitforDockerd:
	sleep 3
	waitforDockerd.sh
_cleanupDiD:
	-docker ps -qa | xargs docker rm -f
	-docker images -qa | xargs docker rmi -f
	-docker system prune -f
	-docker volume prune -f
	-docker network prune -f
	-sudo pkill -f /usr/bin/dockerd
	-sudo rm -f /var/run/docker.pid /var/run/docker.sock

# cares volume mount for RUNNER_TOOL_CACHE... single space for multiple runner instances(replicas/containers)...
#   docker logical volume is created for root(uid:0),  but want to use runner account...
toolcache:
	if [ -n "$${RUNNER_TOOL_CACHE}" ] ; then \
	    mkdir -p $${RUNNER_TOOL_CACHE}; \
	    chown runner:runner $${RUNNER_TOOL_CACHE}; \
	fi

# gh login/logout
# SAMPLE: make login
login login2:
	@(echo ${GH_PAT_RUNNER} | gh auth login --with-token )
	-gh auth status
# SAMPLE: make logout
logout:
	-gh auth logout

# SAMPLE: make config
#  require login
config:
	$(eval url=${rURL})
	$(eval token=$(shell gh api --method POST ${rAPI}/registration-token | jq -r '.token'))
	(cd ${runner_dir}; sudo -EH -u runner ./config.sh --url ${url} --token ${token} --name ${rName} --labels ${label} --runnergroup ${rGroup}  ${rConfigOpts} )

# SAMPLE: make unconfig
#  require login|login2
unconfig:
	$(eval token=$(shell gh api --method POST ${rAPI}/remove-token | jq -r '.token'))
	(cd ${runner_dir}; sudo -EH -u runner ./config.sh remove --token ${token} )
	sleep ${WAIT_MAINTAIN_TEST}

# SAMPLE: make _run
#  require config
_runFG:
	(cd ${runner_dir}; sudo -EH -u runner ./run.sh )
_kill:
	-pkill -f ${runner_dir}/bin/Runner.Listener	
