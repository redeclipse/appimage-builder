#! /bin/bash

docker run \
    -it \
    --rm \
    --cap-add SYS_ADMIN \
    --device /dev/fuse:mrw \
    --security-opt apparmor:unconfined \
    --volume "$(readlink -f .):/vagrant" \
    --env VERSION --env BRANCH \
    debian:wheezy \
    /bin/bash -c "cd /vagrant && ./build-appimage.sh"
