#! /bin/bash

set -e

log() {
    tput setaf 2
    tput bold
    echo "#### $* ####"
    tput sgr0
}

OLD_CWD="$(pwd)"

if [ $(id -u) -ne 0 ]; then
    tput setaf 1
    tput bold
    echo "Error: this script must be run as root!"
    tput sgr0
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export TERM=xterm-256color
export LC_ALL=C
export LANGUAGE=C

export APP=redeclipse
export VERSION=${VERSION:-1.5.9-beta}
export BRANCH=${BRANCH:-stable}
export ARCH=x86_64

export WORKSPACE=/workspace
export PREFIX=$WORKSPACE/redeclipse.AppDir
export DOWNLOADS=$WORKSPACE/downloads
export BUILD=$WORKSPACE/build
export RE_DIR=$PREFIX/usr/lib/$APP

log "VERSION: $VERSION -- BRANCH: $BRANCH"


if [ -d $WORKSPACE ]; then
    tput setaf 3
    tput bold
    echo "Warning: workspace $WORKSPACE already exists!"
    tput sgr0
    read -p "Do you want to purge the workspace before continuing? [y|N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "purging workspace $workspace"
        rm -rf $WORKSPACE
    fi
fi


log "preparing environment"
mkdir -p $WORKSPACE $PREFIX $DOWNLOADS $BUILD


cd $WORKSPACE
log "installing dependencies"

backports=/etc/apt/sources.list.d/jessie.list
if [ ! -f $backports ]; then
    log "enabling jessie repository"
    echo "deb http://http.debian.net/debian jessie main" > $backports
    echo 'APT::Default-Release "stable";' > /etc/apt/apt.conf.d/99defaultrelease
    apt-get update
fi

apt-get install -y --no-install-recommends aptitude autogen ca-certificates \
    cmake fuse gcc g++ git make pkg-config subversion wget xz-utils rsync \
    desktop-file-utils

apt-get install -t jessie -y --no-install-recommends libsdl2-dev \
    libsdl2-image-dev libsdl2-mixer-dev

(cd /tmp && wget -Nc https://github.com/probonopd/AppImages/raw/master/functions.sh)
. /tmp/functions.sh


cd $DOWNLOADS
log "downloading and extracting deb files"
aptitude download libasound2 libsdl2-2.0-0 libsdl2-image-2.0-0 \
    libsdl2-mixer-2.0-0 zlib1g libjpeg62 libpng12-0 libflac8 libogg0 \
    libvorbis0a libpciaccess0 libdrm2 libxcb-dri2-0 libxcb-dri3-0 \
    libxcb-present0 libxcb1 libxau6 libxext6 \
    libx11-6 libx11-xcb1 libxfixes3 libxcb-xfixes0 \
    libxdamage1 libexpat1 libegl1-mesa libgl1-mesa-dri libgl1-mesa-glx \
    libglapi-mesa libgles2-mesa libglu1-mesa libtinfo5

for package in *.deb; do
    dpkg-deb -x $package .
done


cd $BUILD
log "building Red Eclipse"
if [ ! -d .git ]; then
    git clone https://github.com/red-eclipse/base.git -n .
else
    git reset --hard HEAD
    git fetch
fi
git checkout $BRANCH
git submodule update --init
make -C src install-client


log "copying Red Eclipse resources"
mkdir -p $RE_DIR
for dir in bin config data; do
    mkdir -p $RE_DIR/$dir
    rsync -av --delete --exclude .github --exclude .git --delete $BUILD/$dir $RE_DIR
done


log "modifying global variables for AppImage tools"
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
export XDG_DATA_DIRS=$PREFIX/share:$XDG_DATA_DIRS
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH


cd $PREFIX
log "downloading AppRun"
get_apprun

log "copying dependencies and libraries"
copy_deps; copy_deps; copy_deps
rsync -avr --copy-links $DOWNLOADS/{lib,usr} $PREFIX
move_lib
mkdir -p $PREFIX/usr/bin/
rsync -av /bin/bash $PREFIX/usr/bin/


# move PulseAudio libraries as requested in #3
mv $PREFIX/usr/lib/x86_64-linux-gnu/pulseaudio/*.so $PREFIX/usr/lib/x86_64-linux-gnu/


log "delete blacklisted libraries"
(cd $PREFIX/usr/lib/ && delete_blacklisted)
rm -v $PREFIX/usr/lib/x86_64-linux-gnu/lib{xcb,GL,drm,X}*.so.* || true


log "copying desktop file, icon and launcher"
cp $OLD_CWD/$APP{.desktop,.png} $PREFIX/
cp $OLD_CWD/$APP $PREFIX/usr/bin/


log "integrating desktop file"
get_desktopintegration $APP


if [ ! -e /dev/fuse ]; then
    log "setting up fuse"
    mknod -m 666 /dev/fuse c 10 229
fi


cd $WORKSPACE
log "generating appimage"

[ ! -d $OLD_CWD/out ] && mkdir -p $OLD_CWD/out

if [ ! -L $WORKSPACE/../out ]; then
    pushd $WORKSPACE/..
    ln -s $(readlink -f $OLD_CWD/out)
    popd
fi

generate_type2_appimage

[ "$SUDO_UID" == "" ] && export SUDO_UID=1000 && export SUDO_GID=1000
chown $SUDO_UID:$SUDO_GID $OLD_CWD/out/*.AppImage
