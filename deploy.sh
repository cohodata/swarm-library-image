#!/bin/bash
#
# Utility script to deploy local build of swarm to a test cluster
# Example usage:
# $ NODES="swarm-life-v-251-bbm2-1 swarm-life-v-251-bbm2-2" SWARM_REPO=/home/dan/src/gocode/src/github.com/docker/swarm BRANCH=retry-rescheduling ./deploy.sh

set -x

SCRIPTDIR=$(readlink -e "$(dirname $0)")

BRANCH=${BRANCH-master}
SWARM_REPO=${SWARM_REPO-git://git.int.convergent.io/cohodata/swarm.git}

APK_MIRROR=http://nas2.int.convergent.io/alpine/v3.2/main/ \
	  SWARM_REPO="$SWARM_REPO" \
	  PARENT_BUILD_IMG=docker:5000/golang:1.7.1-alpine \
	  "$SCRIPTDIR/update.sh" "$BRANCH"

cleanup() {
    EXITCODE=$?

    rm -f "$SCRIPTDIR/swarm.tar" "$SCRIPTDIR/swarm.tar.gz"
    docker rmi -f deploy-swarm

    return $EXITCODE
}
trap 'cleanup' 0

docker build -t deploy-swarm "$SCRIPTDIR"
docker save --output="$SCRIPTDIR/swarm.tar" deploy-swarm
gzip "$SCRIPTDIR/swarm.tar"

for n in $NODES; do
    ssh root@$n service swarm-manager stop;
    ssh root@$n service swarm-agent stop;
    ssh root@$n docker rm -f swarm-manager swarm-agent;
    ssh root@$n docker rmi registry:5000/coho/swarm:update-go-zookeeper;
done
for n in $NODES; do
    ssh root@$n rm -f swarm.tar.gz swarm.tar
    scp "$SCRIPTDIR/swarm.tar.gz" root@$n:swarm.tar.gz
    ssh root@$n gunzip swarm.tar.gz
    ssh root@$n docker load -i ./swarm.tar
    ssh root@$n docker tag deploy-swarm registry:5000/coho/swarm
    ssh root@$n docker rmi deploy-swarm
    ssh root@$n service swarm-manager start
    ssh root@$n service swarm-agent start
done
