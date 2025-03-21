# github actions selfhost runner

## motivation

this repo aims to get github actions self-hosting runner easily with reproducibility.
i.e. this repo discloses all configs and operations, including Dockerfile, operations to configure/start/stop runner.

## requirements:
- OS: linux or unix
- Softwares: docker and make

## how to use

1) build docker image

```bash
make build
```

2) start container and runner. there are three choices now:

2a) start container, then configure and starts runner process at once.
```bash
make startContainer rTarget=ORG/REPO GH_PAT=your_GITHUB_PersonalAccessToken
```

2b) start step-by-step

```bash
# start container
make startContainer rTarget=ORG/REPO GH_PAT=your_GITHUB_PersonalAccessToken cmd='tail -f /dev/null'

# login to github for getting token to register runner into github.
make login

# configure runner
make config

# start runner process.
make _run
```

2c) start container with systemd, required to make runner support docker tasks.

this usecase is under developing, yet.

```bash
# boot container with systemd
make startContainerWithSystemd rTarget=ORG/REPO GH_PAT=your_GITHUB_PAT

# login, configure, and start runner as service.
make login config _runsvc
```

## hacks

1) garbage collection in runner.

in default, runner doesn't cleanup any garbage collection after job/workflow finished.
it means potential security risk, one can see other's data including credential when workflow invloving login to CI/CD sub system.

there are two choice for garbage collecting.

choice 1) use ephemeral option at config.sh and run.sh.

this ephemeral option simply makes run.sh died at the end of every job, even workflow has multiple jobs.
all it needs to start runner container with 'docker run --restart always' without any volume mount.
then the new runner instance will be created with fresh dist and able to handle next job.

this choice may have limitations:
not sure what happens when workflow request to share the data between jobs, by https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/passing-information-between-jobs

choice 2) use hooks before/after a job

if runner needs to handle multiple jobs in its life cycle, it needs to use hook for clearing garbage.
set env ACTIONS_RUNNER_HOOK_JOB_STARTED and ACTIONS_RUNNER_HOOK_JOB_COMPLETED to hooks/{job-started.sh, job-completed.sh} respectively.
the sample is stored in hooks folder, which passes request to underlying hooks/scripts.d/*-{pre|post}*.sh to handle specific garbage collection.
note that it is difficult to figure out what to clean or keep, since it is depends on user defined content(step/job/workflow/sequence)


## Rerefences

- https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners
- https://qiita.com/yuanying/items/41fbd6df31cce8a6b088

### mandatory scripts for self host runner

- you will get info when you push 'New self-hosted runner' button at https://github.com/ORG/REPO/settings/actions/runners.
i.e. https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz etc.

- some recomends to uses https://github.com/actions/runner-container-hooks if runner handles docker tasks.

### official runner repos?

not sure which is most similar to github hosted (official) runner ;-<

- https://github.com/actions/actions-runner-controller/tree/master/runner or  https://hub.docker.com/r/summerwind/actions-runner/tags
- https://github.com/actions/runner-images https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md
- https://github.com/actions/runner/pkgs/container/actions-runner

### running scripts before / after a job

if no script provided, files/garbages remained and next job gets trouble while its exection.

- https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/running-scripts-before-or-after-a-job
- https://github.com/actions/actions-runner-controller/blob/master/runner/hooks/job-completed.sh
