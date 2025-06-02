#!/bin/bash

usage()
{
    cat <<EOF
Usage: $0 workspace
EOF
    return 0
}

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

account_id=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Assume a role before running this script"
    exit 4
fi

DEV_ACCOUNT="604847260959"
DEVOPS_ACCOUNT="663905530921"

taskName=redmine
workspace=${1}
version=latest

# TODO: make work like rds-ecr
#if [ "$account_id" = "$DEV_ACCOUNT" ]; then
#    target_account=$DEV_ACCOUNT
#else
#    target_account=$DEVOPS_ACCOUNT
#fi
target_account=$account_id

gitHash=$(git log -n 1 --format=%h --abbrev=7)
gitBranch=$(git rev-parse --abbrev-ref HEAD)
gitTag=$(git tag --points-at HEAD)
branch=${gitBranch//\//_}
tag=${gitTag//\//_}
if [[ -z "$tag" ]]; then tagOrBranch=$branch; else tagOrBranch=$tag; fi
if [[ $tagOrBranch == *"release_"* ]]; then isRelease=true; else isRelease=false; fi

if [[ ($version == latest) && ($isRelease == true) ]]; then 
    imageTag=${tagOrBranch}-${gitHash}
else 
    imageTag=${version}-${tagOrBranch}-${gitHash}
fi

region=${AWS_REGION-$(aws configure get region)}
registry="${target_account}.dkr.ecr.$region.amazonaws.com"
image="$registry/$workspace/$taskName:$imageTag"


if docker inspect $image >/dev/null 2>&1; then
    docker rmi $image
fi

set -e
trap 'echo -e "\n\033[0;31mFailed to push image to ecr / update $workspace-$taskName-service\033[0m"; exit 1' ERR

aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry
docker tag hillman-redmine:latest $image
docker push $image

TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition "${workspace}-$taskName" --region "$region")
NEW_TASK_DEFINITION=$(echo $TASK_DEFINITION | jq --arg IMAGE "$image" '.taskDefinition | .containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn) | del(.revision) | del(.status) | del(.requiresAttributes) | del(.compatibilities) |  del(.registeredAt)  | del(.registeredBy)')
NEW_TASK_INFO=$(aws ecs register-task-definition --region "$region" --cli-input-json "$NEW_TASK_DEFINITION")
NEW_REVISION=$(echo $NEW_TASK_INFO | jq '.taskDefinition.revision')
aws ecs update-service --cluster default-fargate --service $workspace-$taskName-service --task-definition ${workspace}-$taskName:${NEW_REVISION} >/dev/null 2>&1
echo -e "\033[0;32mSuccessfully updated $workspace-$taskName-service\033[0m"
