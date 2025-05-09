#!/bin/bash
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if docker inspect hillman-redmine:latest >/dev/null 2>&1; then
    docker rmi hillman-redmine:latest
fi

cd "$script_dir"/..
docker buildx build -t hillman-redmine:latest -f scripts/Dockerfile .
