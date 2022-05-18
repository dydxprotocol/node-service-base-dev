#!/bin/sh
set -euxo pipefail

if [ "$CIRCLE_JOB" == "" ]; then
    echo "version-and-build.sh should only be run in circle"
    exit 1
fi

# GitHub Auth
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
git config --global user.email "ci@dydx.exchange"
git config --global user.name "circle_ci"

# Get version and tag
version=`cat VERSION_STAGING`
git tag v${version}

# Bump version
new_version="$((version + 1))"
echo $new_version > './VERSION_STAGING'
git add VERSION_STAGING
git commit -m "Prep VERSION_STAGING for next build v$new_version [ci skip]"
git push origin staging
git push --tags

# Build docker image
docker build -t $SERVICE_NAME:v$version-staging . --build-arg NPM_TOKEN=${NPM_TOKEN}

# Push to ECR
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag $SERVICE_NAME:v$version-staging $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$SERVICE_NAME:v$version-staging
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$SERVICE_NAME:v$version-staging

# Push to DockerHub
docker tag $SERVICE_NAME:v$version-staging dydxprotocol/$SERVICE_NAME:v$version-staging
docker login -u $DOCKER_HUB_USERNAME -p $DOCKER_HUB_PASSWORD
docker push dydxprotocol/$SERVICE_NAME
