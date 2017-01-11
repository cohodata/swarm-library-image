#!/bin/bash

set -e

if [ $# -eq 0 ] ; then
	echo "Usage: ./update.sh <docker/swarm tag or branch>"
	exit
fi

cleanup() {
    EXITCODE=$?
    echo "Cleaning up.."
    # cleanup build directory
    if [ ! -z "$TEMP" ]; then
	rm -rf "$TEMP"
    fi

    # remove build containers
    if [ ! -z "$BUILDER_ID" ]; then
	docker rm -f "$BUILDER_ID" || :
    fi
    if [ ! -z "$WINBUILDER_ID" ]; then
	docker rm -f "$WINBUILDER_ID" || :
    fi

    # remove build images
    docker rmi swarm-builder:windows || :
    docker rmi swarm-builder || :

    echo "Done."
    return $EXITCODE
}
trap 'cleanup' 0

SWARM_REPO=${SWARM_REPO-https://github.com/docker/swarm.git}

VERSION=$1

# cd to the current directory so the script can be run from anywhere.
cd `dirname $0`

# Update the certificates.
echo "Updating certificates..."
./certs/update.sh

echo "Fetching and building swarm $VERSION..."

# Create a temporary directory.
TEMP=`mktemp -d`

git clone -b $VERSION $SWARM_REPO $TEMP
docker build -t swarm-builder $TEMP

# Create a dummy swarmbuild container so we can run a cp against it.
BUILDER_ID=$(docker create swarm-builder)

# Update the local binary.
docker cp $BUILDER_ID:/go/bin/swarm .

echo "Building swarm.exe $VERSION..."

docker build -t swarm-builder:windows --build-arg GOOS=windows $TEMP

# Create a dummy swarmbuild container so we can run a cp against it.
WINBUILDER_ID=$(docker create swarm-builder:windows)

# Update the local binary.
docker cp $WINBUILDER_ID:/go/bin/windows_amd64/swarm.exe .
mv swarm.exe swarm-unsupported.exe
