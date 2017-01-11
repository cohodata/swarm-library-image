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
PARENT_BUILD_IMG=${PARENT_BUILD_IMG-}
UPDATE_CERTS=${UPDATE_CERTS-}
APK_MIRROR=${APK_MIRROR-}

VERSION=$1

# cd to the current directory so the script can be run from anywhere.
cd `dirname $0`

# Update the certificates.
if [ ! -z "$UPDATE_CERTS" ]; then
    echo "Updating certificates..."
    ./certs/update.sh
fi

echo "Fetching and building swarm $VERSION..."

# Create a temporary directory.
TEMP=`mktemp -d`

git clone -b $VERSION $SWARM_REPO $TEMP
if [ ! -z "$PARENT_BUILD_IMG" ]; then
    sed -i "s~FROM golang:1.7.1-alpine~FROM $PARENT_BUILD_IMG~" "$TEMP/Dockerfile"
fi
if [ ! -z "$APK_MIRROR" ]; then
    sed -i "s~RUN set -ex~RUN set -ex \&\& echo $APK_MIRROR > /etc/apk/repositories~" "$TEMP/Dockerfile"
fi
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
