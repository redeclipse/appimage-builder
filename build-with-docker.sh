#! /bin/bash

set -e

log() {
    (echo -e "\e[91m\e[1m$*\e[0m")
}

cleanup() {
    if [ "$containerid" == "" ]; then
        return 0
    fi

     if [ "$1" == "error" ]; then
        log "error occurred, cleaning up..."
    elif [ "$1" != "" ]; then
        log "$1 received, please wait a few seconds for cleaning up..."
    else
        log "cleaning up..."
    fi

    docker ps -a | grep -q $containerid && docker rm -f $containerid
}

trap "cleanup SIGINT" SIGINT
trap "cleanup SIGTERM" SIGTERM
trap "cleanup error" 0
trap "cleanup" EXIT

if [ -z "$1" ]; then
    log "Usage: build-with-docker.sh <path to source and data>"
    exit 1
fi

log "Using source: $1"
test -e "$1/src/engine/version.h" || ( log "No version.h found"; exit 1 )

log  "Building in a container..."

randstr=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
containerid=redeclipse-appimage-build-$randstr
imageid="redeclipse-appimage-build"

log "Building Docker container"
(set -xe; docker build -t $imageid --build-arg user_id=$(id -u) --build-arg group_id=$(id -g) .)

export VERSION BRANCH ARCH REPO_URL BUILD_CLIENT BUILD_SERVER

log "Creating container $containerid"
mkdir -p out/
chmod o+rwx,u+s out/
set -xe
docker run -it \
    --name $containerid \
    -v "$(readlink -f out/):/out" \
    -v "$(readlink -f "$1"):/source" \
    -e VERSION -e BRANCH -e ARCH -e REPO_URL -e BUILD_CLIENT -e BUILD_SERVER \
    -e PLATFORM_BUILD -e PLATFORM_BRANCH -e PLATFORM_REVISION \
    $imageid \
    bash -x /build-appimages.sh || exit 1
