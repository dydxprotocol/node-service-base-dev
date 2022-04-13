#!/bin/sh
set -euxo pipefail

if [ "$CIRCLE_JOB" == "" ]; then
    echo "version-and-build.sh should only be run in circle"
    exit 1
fi

# Install AWS cli
apk -Uuv add --no-cache sudo openssh docker
sudo pip install --upgrade pip
sudo pip install awscli

# GitHub Auth
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
git config --global user.email "ci@dydx.exchange"
git config --global user.name "circle_ci"

# Get version and tag
version=`cat VERSION`
git tag v${version}

# Bump version
new_version="$((version + 1))"
echo $new_version > './VERSION'
git add VERSION
git commit -m "Prep VERSION for next build v$new_version [ci skip]" --no-verify
git push origin master
git push --tags

# Build docker image
docker build -t $SERVICE_NAME:v$version . --build-arg NPM_TOKEN=${NPM_TOKEN}

# Push to DockerHub
docker tag $SERVICE_NAME:v$version dydxprotocol/$SERVICE_NAME:v$version
docker login -u $DOCKER_HUB_USERNAME -p $DOCKER_HUB_PASSWORD
docker push dydxprotocol/$SERVICE_NAME

# Push to ECR
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag $SERVICE_NAME:v$version $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$SERVICE_NAME:v$version
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$SERVICE_NAME:v$version
