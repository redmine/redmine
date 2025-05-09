#!/bin/bash
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$script_dir"/..

export REDMINE_NO_DB_MIGRATE=true
export RAILS_ENV=development

docker run -it --rm \
    -p 3000:3000 \
    -e REDMINE_NO_DB_MIGRATE \
    -e RAILS_ENV \
    -v $(pwd)/app:/usr/src/redmine/app \
    -v $(pwd)/config:/usr/src/redmine/config \
    --entrypoint rails \
    hillman-redmine:latest \
    server -b 0.0.0.0
