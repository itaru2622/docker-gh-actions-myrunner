#!/bin/bash

#cmd="$1"
max_time_wait=30
waited_sec=0

while ! docker ps -qa >/dev/null && ((waited_sec < max_time_wait)); do
        echo "Process $process_name is not running yet. Retrying in 1 seconds"
        echo "Waited $waited_sec seconds of $max_time_wait seconds"
        sleep 1
        ((waited_sec=waited_sec+1))
        if ((waited_sec >= max_time_wait)); then
            ps auwx
            cat /var/run/docker.pid
            exit 1
        fi
done
exit 0
