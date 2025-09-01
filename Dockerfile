# github actions selfhost runner
#
# https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners
# https://zenn.dev/kesin11/articles/20230514_container_hooks

ARG base=ubuntu:24.04
FROM ${base}
ARG base=ubuntu:24.04


RUN apt update; apt install -y curl unzip gnupg jq yq

# starts: github actions self-host runner >>>>>>>>>>>>>>>
ARG runner_dir=/opt/gh-action-runner
WORKDIR ${runner_dir}

# download latest version of actions/runner, actions/runner-container-hooks
RUN curl -L https://api.github.com/repos/actions/runner/releases/latest | jq -r '.assets[].browser_download_url' | grep linux-x64 | grep tar.gz | xargs -I {} curl -L {} -o /tmp/actions-runner.tgz
RUN curl -L https://api.github.com/repos/actions/runner-container-hooks/releases/latest |  jq -r '.assets[].browser_download_url' | grep hooks-docker | grep zip | xargs -I {} curl -L {} -o  /tmp/runner-container-hooks.zip

RUN tar zxvf /tmp/actions-runner.tgz; \
    unzip /tmp/runner-container-hooks.zip -d ${runner_dir}/runner-container-hooks-docker; \
    rm -f /tmp/actions-runner.tgz /tmp/runner-container-hooks.zip

ENV  ACTIONS_RUNNER_CONTAINER_HOOKS=${runner_dir}/runner-container-hooks-docker/index.js
ENV  PATH=${PATH}:${runner_dir}/bin:${runner_dir}
# cf. https://github.com/actions/runner/blob/main/images/Dockerfile
ENV  RUNNER_MANUALLY_TRAP_SIG=1
#ENV  ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
# cf. toolcache https://i-beam.org/2024/05/25/github-actions-tool-cache/
ENV  RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir -p ${RUNNER_TOOL_CACHE}

# ends: github actions self-host runner <<<<<<<<<<<<<<<

# starts: runner capability (docker in docker) >>>>
RUN curl -L https://download.docker.com/linux/ubuntu/gpg > /etc/apt/trusted.gpg.d/docker.asc; \
    echo "deb [arch=$(dpkg --print-architecture) ] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    tee -a /etc/apt/sources.list.d/docker.list;
RUN apt update; apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin  kmod    iproute2 iptables;
ENV DOCKER_DRIVER=vfs
# ends: runner capability (docker in docker) >>>>

# starts: other runner capability
#    gh
RUN curl -L https://cli.github.com/packages/githubcli-archive-keyring.gpg > /etc/apt/trusted.gpg.d/github-cli.gpg ;\
    echo "deb https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; 
#    download latest version of msgraph
RUN curl -L https://api.github.com/repos/microsoftgraph/msgraph-cli/releases/latest |  jq -r '.assets[].browser_download_url' | grep linux-x64 | grep tar.gz | xargs -I {} echo curl -L {} -o /tmp/msgcli.tgz; \
    tar zxvf /tmp/msgcli.tgz -C /usr/local/bin ; rm -f  /tmp/msgcli.tgz
#    azure-cli; https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

RUN apt update; apt install -y gh git make expect parallel        bash-completion sudo vim
# ends: other runner capability

# user for runner
ARG uid=1000
ARG uname=runner
RUN deluser  --remove-home --remove-all-files ubuntu; delgroup ubuntu; \
    addgroup --system --gid ${uid} ${uname} ; \
    adduser  --disabled-password --system --gid ${uid} --uid ${uid} --shell /bin/bash --home /home/${uname} ${uname} ; \
    usermod  -aG docker ${uname} ; \
    (cd /etc/skel; find . -type f -print | tar cf - -T - | tar xvf - -C/home/${uname} ) ; \
    echo "${uname} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/local-user; \
    echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers; \
    mkdir -p /home/${uname}/.ssh  /home/${uname}/.config /run/gh-runner;\
    echo "set mouse-=a" > /home/${uname}/.vimrc; \
    chown -R ${uname}:${uname} /home/${uname} ${runner_dir} ${RUNNER_TOOL_CACHE} /run/gh-runner
USER ${uname}

COPY . /work
WORKDIR /work

ENV ACTIONS_RUNNER_HOOK_JOB_STARTED=/work/hooks/job-started.sh
ENV ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/work/hooks/job-completed.sh
ENV STATUS_JOB_RUNNING=/run/gh-runner/status.job-running
