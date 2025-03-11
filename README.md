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

1) hooks before/after a job

both of ACTIONS_RUNNER_HOOK_JOB_STARTED and ACTIONS_RUNNER_HOOK_JOB_COMPLETED bounded to
hooks/{job-started.sh, job-completed.sh} respectively.
those two scripts load and kick hooks/scripts.d/*-{pre|post}*.sh to handle specific garbage collection.


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
